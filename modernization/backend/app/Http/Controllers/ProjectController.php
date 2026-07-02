<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProjectRequest;
use App\Models\ApplicationBatch;
use App\Models\DictionaryItem;
use App\Models\Message;
use App\Models\Project;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\ProjectFileStorage;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProjectController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        if (! Role::userCan($request->user(), 'view_projects')) {
            abort(403, '无权访问项目');
        }

        $query = Project::query()->with(['unit', 'owner', 'applicationBatch']);

        if ($request->user()->role === Role::UNIT) {
            $query->where('unit_id', $request->user()->unit_id);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($category = $request->query('category')) {
            $query->whereIn('category', $this->dictionaryEquivalentValues('project_category', $category));
        }

        if ($projectType = $request->query('project_type')) {
            $query->whereIn('project_type', $this->dictionaryEquivalentValues('project_type', $projectType));
        }

        if ($batchId = $request->query('application_batch_id', $request->query('batch_id'))) {
            $query->where('application_batch_id', $batchId);
        }

        if ($request->filled('unit_id') && in_array($request->user()->role, Role::adminRoles(), true)) {
            $query->where('unit_id', $request->query('unit_id'));
        }

        if ($request->boolean('pending_extension')) {
            $query->where(function ($query) {
                $query->where('metadata', 'like', '%"status":"pending"%')
                    ->orWhere('metadata', 'like', '%"status": "pending"%')
                    ->orWhere(function ($query) {
                        $query->where('metadata', 'like', '%"extension_requests"%')
                            ->where('metadata', 'not like', '%"status"%');
                    });
            });
        }

        if ($request->has('e2e')) {
            $request->boolean('e2e')
                ? $query->where(fn ($query) => $this->e2eProjectQuery($query))
                : $query->where(fn ($query) => $this->nonE2eProjectQuery($query));
        }

        if ($request->filled('keyword')) {
            $keyword = $request->query('keyword');
            $query->where(function ($query) use ($keyword) {
                $query->where('title', 'like', "%{$keyword}%")
                    ->orWhere('project_type', 'like', "%{$keyword}%")
                    ->orWhere('category', 'like', "%{$keyword}%")
                    ->orWhereHas('unit', function ($query) use ($keyword) {
                        $query->where('name', 'like', "%{$keyword}%")
                            ->orWhere('credit_code', 'like', "%{$keyword}%");
                    })
                    ->orWhereHas('owner', function ($query) use ($keyword) {
                        $query->where('username', 'like', "%{$keyword}%");
                    });
            });
        }

        return $query->orderBy('created_at')
            ->orderBy('id')
            ->paginate(20)
            ->through(function (Project $project) {
                $project->pending_extension_requests_count = $project->pendingExtensionRequestsCount();

                return $project;
            });
    }

    public function options(Request $request)
    {
        if (! Role::userCan($request->user(), 'view_projects')) {
            abort(403, '无权访问项目');
        }

        $query = $this->visibleProjectsQuery($request)
            ->with(['unit:id,name', 'applicationBatch:id,name,code'])
            ->select([
                'id',
                'unit_id',
                'application_batch_id',
                'legacy_id',
                'title',
                'status',
                'metadata',
                'submitted_at',
                'updated_at',
            ]);

        if ($request->filled('keyword')) {
            $keyword = $request->query('keyword');
            $query->where(function ($query) use ($keyword): void {
                $query->where('title', 'like', "%{$keyword}%")
                    ->orWhere('legacy_id', 'like', "%{$keyword}%")
                    ->orWhere('id', $keyword)
                    ->orWhereHas('unit', fn ($query) => $query->where('name', 'like', "%{$keyword}%"))
                    ->orWhereHas('applicationBatch', fn ($query) => $query
                        ->where('name', 'like', "%{$keyword}%")
                        ->orWhere('code', 'like', "%{$keyword}%"));
            });
        }

        if ($request->filled('batch_id')) {
            $query->where('application_batch_id', $request->query('batch_id'));
        }

        if ($request->filled('unit_id') && in_array($request->user()->role, Role::adminRoles(), true)) {
            $query->where('unit_id', $request->query('unit_id'));
        }

        if ($request->filled('status')) {
            $query->whereIn('status', array_filter(explode(',', (string) $request->query('status'))));
        }

        if ($request->query('context') === 'rectification') {
            $query->whereIn('status', [
                Project::STATUS_APPROVED,
                Project::STATUS_ACCEPTANCE,
            ]);
        } elseif ($request->query('context') === 'acceptance') {
            $query->whereIn('status', [
                Project::STATUS_APPROVED,
                Project::STATUS_ACCEPTANCE,
            ]);
        }

        $limit = min(max((int) $request->query('limit', 20), 1), 50);

        return $query
            ->latest('updated_at')
            ->limit($limit)
            ->get()
            ->map(fn (Project $project) => [
                'id' => $project->id,
                'title' => $project->title,
                'code' => $project->metadata['project_code'] ?? $project->legacy_id ?? 'P'.$project->id,
                'status' => $project->status,
                'unit' => $project->unit ? [
                    'id' => $project->unit->id,
                    'name' => $project->unit->name,
                ] : null,
                'batch' => $project->applicationBatch ? [
                    'id' => $project->applicationBatch->id,
                    'name' => $project->applicationBatch->name,
                    'code' => $project->applicationBatch->code,
                ] : null,
            ]);
    }

    public function store(StoreProjectRequest $request)
    {
        $this->authorizeUnitApplicant($request);

        $user = $request->user();
        $data = $request->validated();
        $batch = $this->resolveOpenBatch($data['application_batch_id'] ?? null);
        $this->ensureBatchAllowsProject($batch, $data);
        $data = $this->normalizeProjectDictionaryFields($data);
        $data['application_batch_id'] = $batch->id;

        $project = Project::create($data + [
            'unit_id' => $user->unit_id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);

        $this->auditLogger->record($request, 'project.created', $project);

        return response()->json($project->load(['unit', 'owner']), 201);
    }

    public function show(Request $request, Project $project)
    {
        $this->authorizeProjectAccess($request, $project);

        $project->load([
            'unit', 'owner',
            'applicationBatch',
            'files' => fn ($q) => $q->latest(),
            'reviews' => fn ($q) => $q->with('reviewer')->latest('reviewed_at'),
            'acceptanceApplications' => fn ($q) => $q->with(['submitter', 'reviews.reviewer'])->latest(),
        ]);

        $project->setAttribute('timeline', $this->projectTimeline($project));

        return $project;
    }

    public function update(StoreProjectRequest $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if (! in_array($project->status, [Project::STATUS_DRAFT, Project::STATUS_RETURNED], true)) {
            return response()->json(['message' => '当前状态不允许修改'], 422);
        }

        $data = $request->validated();
        if (array_key_exists('application_batch_id', $data) && $data['application_batch_id']) {
            $batch = $this->resolveOpenBatch($data['application_batch_id']);
            $this->ensureBatchAllowsProject($batch, $data + $project->only(['category', 'project_type']));
        } elseif (array_key_exists('application_batch_id', $data)) {
            unset($data['application_batch_id']);
        }
        $data = $this->normalizeProjectDictionaryFields($data);

        $project->update($data);

        $this->auditLogger->record($request, 'project.updated', $project);

        return $project->refresh()->load(['unit', 'owner', 'applicationBatch']);
    }

    public function destroy(Request $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if ($project->status !== Project::STATUS_DRAFT) {
            return response()->json(['message' => '只有草稿项目可以删除'], 422);
        }

        $files = $project->files()->get();
        $deletedFileCount = 0;
        $invalidFileCount = 0;

        $files->each(function ($file) use ($request, &$deletedFileCount, &$invalidFileCount): void {
            if (! ProjectFileStorage::isAllowedDisk($file)) {
                $invalidFileCount++;
                $this->auditLogger->record($request, 'project_file.invalid_disk', $file, [
                    'disk' => $file->disk,
                    'path' => $file->path,
                ]);

                return;
            }

            if (! ProjectFileStorage::isAllowedPath($file)) {
                $invalidFileCount++;
                $this->auditLogger->record($request, 'project_file.invalid_path', $file, [
                    'disk' => $file->disk,
                    'path' => $file->path,
                ]);

                return;
            }

            Storage::disk($file->disk)->delete($file->path);
            $deletedFileCount++;
        });

        $this->auditLogger->record($request, 'project.deleted', $project, [
            'deleted_file_count' => $deletedFileCount,
            'skipped_invalid_file_count' => $invalidFileCount,
        ]);
        $project->delete();

        return response()->noContent();
    }

    public function submit(Request $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if (! in_array($project->status, [Project::STATUS_DRAFT, Project::STATUS_RETURNED], true)) {
            return response()->json(['message' => '当前状态不允许提交'], 422);
        }

        $batch = $project->applicationBatch ?: $this->resolveOpenBatch($project->application_batch_id);
        if (! $batch->isOpenNow()) {
            return response()->json(['message' => '申报批次未开放，不能提交'], 422);
        }
        $this->ensureBatchAllowsProject($batch, $project->only(['category', 'project_type']));

        $project->update([
            'status' => Project::STATUS_SUBMITTED,
            'submitted_at' => now(),
            'current_reviewer_role' => Role::COUNTY,
        ]);

        $this->auditLogger->record($request, 'project.submitted', $project);
        $this->notifyOwner($project, '项目已提交', '项目已进入区县审核阶段。');
        $this->notifyRole($project, Role::COUNTY, '收到待审项目', '项目“'.$project->title.'”已提交，请及时审核。');

        return $project->refresh();
    }

    public function withdraw(Request $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if ($project->status !== Project::STATUS_SUBMITTED) {
            return response()->json(['message' => '只有已提交且未审核的项目可以撤回'], 422);
        }

        $project->update(['status' => Project::STATUS_DRAFT, 'current_reviewer_role' => null]);

        $this->auditLogger->record($request, 'project.withdrawn', $project);

        return $project->refresh();
    }

    public function enterAcceptance(Request $request, Project $project)
    {
        $this->authorizeAdminProjectAction($request);
        $this->authorizeProjectAccess($request, $project);

        if ($project->status !== Project::STATUS_APPROVED) {
            return response()->json(['message' => '只有已通过项目可以进入验收'], 422);
        }

        $project->update(['status' => Project::STATUS_ACCEPTANCE]);
        $this->auditLogger->record($request, 'project.acceptance_started', $project);
        $this->notifyOwner($project, '项目进入验收', '项目已进入验收阶段，请按要求提交验收材料。');

        return $project->refresh();
    }

    public function close(Request $request, Project $project)
    {
        $this->authorizeAdminProjectAction($request);
        $this->authorizeProjectAccess($request, $project);

        if ($project->status !== Project::STATUS_ACCEPTANCE) {
            return response()->json(['message' => '只有验收阶段项目可以关闭'], 422);
        }

        if ($project->pendingExtensionRequestsCount() > 0) {
            return response()->json(['message' => '存在待处理延期申请，不能关闭验收'], 422);
        }

        $data = $request->validate([
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $metadata = $project->metadata ?? [];
        $metadata['acceptance_closed'] = [
            'comment' => $data['comment'] ?? null,
            'closed_at' => now()->toDateTimeString(),
            'closed_by' => $request->user()->id,
        ];

        $project->update(['status' => Project::STATUS_CLOSED, 'metadata' => $metadata]);
        $this->auditLogger->record($request, 'project.closed', $project, ['comment' => $data['comment'] ?? null]);
        $this->notifyOwner($project, '项目已完成验收', '项目验收已关闭。'.($data['comment'] ?? ''));

        return $project->refresh();
    }

    public function requestExtension(Request $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if (! in_array($project->status, [Project::STATUS_APPROVED, Project::STATUS_ACCEPTANCE], true)) {
            return response()->json(['message' => '当前状态不允许申请延期'], 422);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:3000'],
            'expected_date' => ['nullable', 'date'],
        ]);

        $metadata = $project->metadata ?? [];
        $extensions = $metadata['extension_requests'] ?? [];
        $extensions[] = [
            'reason' => $data['reason'],
            'expected_date' => $data['expected_date'] ?? null,
            'status' => 'pending',
            'requested_at' => now()->toDateTimeString(),
            'requested_by' => $request->user()->id,
        ];
        $metadata['extension_requests'] = $extensions;

        $project->update(['metadata' => $metadata]);
        $this->auditLogger->record($request, 'project.extension_requested', $project, [
            'expected_date' => $data['expected_date'] ?? null,
        ]);
        $this->notifyAdmins($project, '收到延期申请', '项目“'.$project->title.'”收到延期申请，请及时处理。');

        return $project->refresh();
    }

    public function reviewExtension(Request $request, Project $project, int $index)
    {
        $this->authorizeAdminProjectAction($request);
        $this->authorizeProjectAccess($request, $project);

        $metadata = $project->metadata ?? [];
        $extensions = $metadata['extension_requests'] ?? [];

        if (! array_key_exists($index, $extensions)) {
            return response()->json(['message' => '延期申请不存在'], 404);
        }

        if (($extensions[$index]['status'] ?? 'pending') !== 'pending') {
            return response()->json(['message' => '延期申请已处理'], 422);
        }

        $data = $request->validate([
            'decision' => ['required', 'in:approved,rejected'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $extensions[$index] = array_merge($extensions[$index], [
            'status' => $data['decision'],
            'review_comment' => $data['comment'] ?? null,
            'reviewed_at' => now()->toDateTimeString(),
            'reviewed_by' => $request->user()->id,
        ]);
        $metadata['extension_requests'] = $extensions;

        $project->update(['metadata' => $metadata]);

        $this->auditLogger->record($request, 'project.extension_reviewed', $project, [
            'extension_index' => $index,
            'decision' => $data['decision'],
            'expected_date' => $extensions[$index]['expected_date'] ?? null,
        ]);

        $title = $data['decision'] === 'approved' ? '延期申请已通过' : '延期申请已驳回';
        $this->notifyOwner($project, $title, $title.'。'.($data['comment'] ?? ''));

        return $project->refresh();
    }

    private function notifyOwner(Project $project, string $title, string $body): void
    {
        Message::create([
            'recipient_id' => $project->owner_id,
            'project_id' => $project->id,
            'type' => 'project',
            'title' => $title,
            'body' => $body,
        ]);
    }

    private function notifyAdmins(Project $project, string $title, string $body): void
    {
        $this->notifyRole($project, Role::ADMIN, $title, $body);
    }

    private function notifyRole(Project $project, string $role, string $title, string $body): void
    {
        User::query()
            ->where(function ($query) use ($role): void {
                $query->where('role', $role);
                if ($role === Role::ADMIN) {
                    $query->orWhere('role', Role::SUPER_ADMIN);
                }
            })
            ->where('is_active', true)
            ->each(function (User $user) use ($project, $title, $body): void {
                Message::create([
                    'recipient_id' => $user->id,
                    'project_id' => $project->id,
                    'type' => 'project',
                    'title' => $title,
                    'body' => $body,
                ]);
            });
    }

    private function authorizeAdminProjectAction(Request $request): void
    {
        if (! in_array($request->user()->role, Role::adminRoles(), true)) {
            abort(403, '只有管理员可以处理项目验收');
        }
    }

    private function visibleProjectsQuery(Request $request)
    {
        $user = $request->user();
        $query = Project::query();

        if ($user->role === Role::UNIT) {
            return $query->where('unit_id', $user->unit_id);
        }

        if (in_array($user->role, [Role::COUNTY, Role::DEPARTMENT, Role::EXPERT], true)) {
            $stage = Role::reviewerStageFor($user->role);

            return $query->where(function ($query) use ($stage): void {
                $query->where('current_reviewer_role', $stage)
                    ->orWhereHas('reviews', fn ($query) => $query->where('stage', $stage));
            });
        }

        return $query;
    }

    private function projectTimeline(Project $project): array
    {
        $project->loadMissing(['reviews.reviewer', 'acceptanceApplications.reviews.reviewer']);
        $reviews = $project->reviews->keyBy('stage');
        $acceptance = $project->acceptanceApplications->first();

        $stages = [
            ['key' => 'submitted', 'label' => '单位提交', 'role' => Role::UNIT],
            ['key' => Role::COUNTY, 'label' => '区县审核', 'role' => Role::COUNTY],
            ['key' => Role::DEPARTMENT, 'label' => '部门审核', 'role' => Role::DEPARTMENT],
            ['key' => Role::EXPERT, 'label' => '专家评审', 'role' => Role::EXPERT],
            ['key' => Role::ADMIN, 'label' => '科技局终审', 'role' => Role::ADMIN],
            ['key' => 'acceptance', 'label' => '验收阶段', 'role' => null],
        ];

        return collect($stages)->map(function (array $stage) use ($project, $reviews, $acceptance): array {
            if ($stage['key'] === 'submitted') {
                return [
                    ...$stage,
                    'status' => $project->submitted_at ? 'done' : 'pending',
                    'handler' => $project->owner?->name ?: $project->owner?->username,
                    'handled_at' => $project->submitted_at?->toDateTimeString(),
                    'decision' => $project->submitted_at ? 'submitted' : null,
                    'comment' => null,
                ];
            }

            if ($stage['key'] === 'acceptance') {
                return [
                    ...$stage,
                    'status' => $acceptance ? 'done' : ($project->status === Project::STATUS_APPROVED ? 'current' : 'pending'),
                    'handler' => $acceptance?->submitter?->name ?: $acceptance?->submitter?->username,
                    'handled_at' => $acceptance?->submitted_at?->toDateTimeString(),
                    'decision' => $acceptance?->status,
                    'comment' => $acceptance?->summary,
                ];
            }

            $review = $reviews->get($stage['key']);

            return [
                ...$stage,
                'status' => $review ? 'done' : ($project->current_reviewer_role === $stage['key'] ? 'current' : 'pending'),
                'handler' => $review?->reviewer?->name ?: $review?->reviewer?->username,
                'handled_at' => $review?->reviewed_at?->toDateTimeString(),
                'decision' => $review?->decision,
                'score' => $review?->score,
                'comment' => $review?->comment,
            ];
        })->all();
    }

    private function authorizeProjectAccess(Request $request, Project $project): void
    {
        $user = $request->user();

        if (! Role::userCan($user, 'view_projects')) {
            abort(403, '无权访问项目');
        }

        if ($user->role === Role::UNIT && $project->unit_id !== $user->unit_id) {
            abort(403, '无权访问该项目');
        }
    }

    private function authorizeProjectWrite(Request $request, Project $project): void
    {
        $this->authorizeProjectAccess($request, $project);
        $this->authorizeUnitApplicant($request);
    }

    private function authorizeUnitApplicant(Request $request): void
    {
        $user = $request->user();

        if ($user->role !== Role::UNIT || ! $user->unit_id) {
            abort(403, '只有单位用户可以维护申报项目');
        }

        if ($user->loadMissing('unit')->unit?->status !== 'active') {
            abort(403, '单位已停用，无法维护申报项目');
        }
    }

    private function resolveOpenBatch(?int $batchId = null): ApplicationBatch
    {
        $query = ApplicationBatch::query()
            ->where('status', ApplicationBatch::STATUS_OPEN)
            ->where(function ($query): void {
                $query->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            });

        if ($batchId) {
            $batch = (clone $query)->whereKey($batchId)->first();
            if (! $batch) {
                abort(422, '所选申报批次未开放');
            }

            return $batch;
        }

        $batches = $query->limit(2)->get();
        if ($batches->count() === 1) {
            return $batches->first();
        }

        abort(422, '请选择当前开放的申报批次');
    }

    private function ensureBatchAllowsProject(ApplicationBatch $batch, array $data): void
    {
        $categories = is_array($batch->allowed_categories) ? array_filter($batch->allowed_categories) : [];
        $types = is_array($batch->allowed_project_types) ? array_filter($batch->allowed_project_types) : [];

        if ($categories && ! $this->dictionaryValueAllowed('project_category', $data['category'] ?? null, $categories)) {
            abort(422, '项目类别不在当前批次允许范围内');
        }

        if ($types && ! $this->dictionaryValueAllowed('project_type', $data['project_type'] ?? null, $types)) {
            abort(422, '项目类型不在当前批次允许范围内');
        }
    }

    private function normalizeProjectDictionaryFields(array $data): array
    {
        if (array_key_exists('category', $data)) {
            $data['category'] = $this->dictionaryDisplayValue('project_category', $data['category']);
        }

        if (array_key_exists('project_type', $data)) {
            $data['project_type'] = $this->dictionaryDisplayValue('project_type', $data['project_type']);
        }

        return $data;
    }

    private function dictionaryDisplayValue(string $group, mixed $value): mixed
    {
        if ($value === null || $value === '') {
            return $value;
        }

        $text = (string) $value;
        $item = DictionaryItem::query()
            ->where('group', $group)
            ->where(function ($query) use ($text): void {
                $query->where('code', $text)->orWhere('label', $text);
            })
            ->first();

        return $item?->label ?: $text;
    }

    private function dictionaryValueAllowed(string $group, mixed $value, array $allowedValues): bool
    {
        if ($value === null || $value === '') {
            return false;
        }

        $valueEquivalents = $this->dictionaryEquivalentValues($group, $value);
        foreach ($allowedValues as $allowedValue) {
            if (array_intersect($valueEquivalents, $this->dictionaryEquivalentValues($group, $allowedValue))) {
                return true;
            }
        }

        return false;
    }

    private function dictionaryEquivalentValues(string $group, mixed $value): array
    {
        if ($value === null || $value === '') {
            return [''];
        }

        $text = (string) $value;
        $values = [$text];
        $item = DictionaryItem::query()
            ->where('group', $group)
            ->where(function ($query) use ($text): void {
                $query->where('code', $text)->orWhere('label', $text);
            })
            ->first();

        if ($item) {
            $values[] = $item->code;
            $values[] = $item->label;
        }

        return array_values(array_unique(array_filter($values, fn ($item) => $item !== null && $item !== '')));
    }

    private function e2eProjectQuery($query): void
    {
        $query->where('metadata', 'like', '%"e2e":true%')
            ->orWhere('metadata', 'like', '%"e2e": true%')
            ->orWhere('title', 'like', '%E2E-%')
            ->orWhereHas('applicationBatch', fn ($query) => $this->e2eBatchRelationQuery($query));
    }

    private function nonE2eProjectQuery($query): void
    {
        $query->where(function ($query): void {
            $query->whereNull('metadata')
                ->orWhere(function ($query): void {
                    $query->where('metadata', 'not like', '%"e2e":true%')
                        ->where('metadata', 'not like', '%"e2e": true%');
                });
        })
            ->where('title', 'not like', '%E2E-%')
            ->whereDoesntHave('applicationBatch', fn ($query) => $this->e2eBatchRelationQuery($query));
    }

    private function e2eBatchRelationQuery($query): void
    {
        $query->where('name', 'like', '%E2E-%')
            ->orWhere('code', 'like', '%E2E-%')
            ->orWhere('metadata', 'like', '%"e2e":true%')
            ->orWhere('metadata', 'like', '%"e2e": true%');
    }
}
