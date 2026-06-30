<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProjectFileRequest;
use App\Models\AcceptanceApplication;
use App\Models\AcceptanceExtension;
use App\Models\AcceptanceReview;
use App\Models\Message;
use App\Models\Project;
use App\Models\ProjectFile;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;

class AcceptanceController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        if (! $this->canView($request)) {
            abort(403, '无权查看验收管理');
        }

        $query = AcceptanceApplication::query()
            ->with(['project.unit', 'unit', 'submitter'])
            ->latest();

        if ($request->user()->role === Role::UNIT) {
            $query->where('unit_id', $request->user()->unit_id);
        } elseif (in_array($request->user()->role, [Role::COUNTY, Role::DEPARTMENT, Role::EXPERT], true)) {
            $query->where('current_reviewer_role', $request->user()->role);
        } elseif ($request->user()->role === Role::SUPER_ADMIN && $request->boolean('tasks_only')) {
            $query->where('current_reviewer_role', Role::ADMIN);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($request->filled('project_id')) {
            $query->where('project_id', $request->query('project_id'));
        }

        if ($keyword = $request->query('keyword')) {
            $query->whereHas('project', function ($query) use ($keyword): void {
                $query->where('title', 'like', '%'.$keyword.'%')
                    ->orWhereHas('unit', fn ($query) => $query->where('name', 'like', '%'.$keyword.'%'));
            });
        }

        return $query->paginate(20);
    }

    public function show(Request $request, AcceptanceApplication $acceptance)
    {
        $this->authorizeAccess($request, $acceptance);

        $acceptance->load([
            'project.unit',
            'project.owner',
            'unit',
            'submitter',
            'reviews.reviewer',
            'extensions',
            'project.files' => fn ($query) => $query->where('purpose', 'acceptance')->latest(),
        ]);

        $acceptance->setAttribute('timeline', $this->acceptanceTimeline($acceptance));

        return $acceptance;
    }

    public function store(Request $request, Project $project)
    {
        $this->authorizeUnitProject($request, $project);

        if (! in_array($project->status, [Project::STATUS_APPROVED, Project::STATUS_ACCEPTANCE], true)) {
            return response()->json(['message' => '只有已通过或验收中项目可以发起验收'], 422);
        }

        $data = $request->validate([
            'summary' => ['nullable', 'string', 'max:5000'],
            'metadata' => ['nullable', 'array'],
        ]);

        $acceptance = AcceptanceApplication::firstOrCreate(
            [
                'project_id' => $project->id,
                'status' => AcceptanceApplication::STATUS_DRAFT,
            ],
            [
                'unit_id' => $project->unit_id,
                'submitted_by' => $request->user()->id,
                'summary' => $data['summary'] ?? null,
                'metadata' => $data['metadata'] ?? [],
            ]
        );

        $project->update(['status' => Project::STATUS_ACCEPTANCE]);
        $this->auditLogger->record($request, 'acceptance.created', $acceptance, ['project_id' => $project->id]);

        return response()->json($acceptance->load('project.unit'), 201);
    }

    public function submit(Request $request, AcceptanceApplication $acceptance)
    {
        $this->authorizeUnitAcceptance($request, $acceptance);

        if (! in_array($acceptance->status, [AcceptanceApplication::STATUS_DRAFT, AcceptanceApplication::STATUS_RETURNED], true)) {
            return response()->json(['message' => '当前状态不允许提交验收'], 422);
        }

        $data = $request->validate([
            'summary' => ['nullable', 'string', 'max:5000'],
        ]);

        $acceptance->update([
            'summary' => $data['summary'] ?? $acceptance->summary,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => Role::COUNTY,
            'submitted_at' => now(),
        ]);
        $acceptance->project()->update(['status' => Project::STATUS_ACCEPTANCE]);

        $this->auditLogger->record($request, 'acceptance.submitted', $acceptance);
        $this->notifyRole($acceptance, Role::COUNTY, '收到待审验收', '项目“'.$acceptance->project->title.'”已提交验收申请。');

        return $acceptance->refresh()->load('project.unit');
    }

    public function review(Request $request, AcceptanceApplication $acceptance)
    {
        $this->authorizeReview($request, $acceptance);

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject,close'],
            'score' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'comment' => ['nullable', 'string', 'max:3000'],
            'metadata' => ['nullable', 'array'],
        ]);

        $stage = Role::reviewerStageFor($request->user()->role);
        $review = AcceptanceReview::create($data + [
            'acceptance_application_id' => $acceptance->id,
            'reviewer_id' => $request->user()->id,
            'stage' => $stage,
            'reviewed_at' => now(),
        ]);

        $acceptance->update($this->nextAcceptanceState($acceptance, $data['decision']));
        if (in_array($acceptance->status, [AcceptanceApplication::STATUS_APPROVED, AcceptanceApplication::STATUS_CLOSED], true)) {
            $acceptance->project()->update(['status' => Project::STATUS_CLOSED]);
        }

        $this->auditLogger->record($request, 'acceptance.reviewed', $review, [
            'acceptance_id' => $acceptance->id,
            'decision' => $data['decision'],
        ]);
        $this->notifyOwner($acceptance, '验收审核状态更新', '审核结果：'.$data['decision'].'。'.($data['comment'] ?? ''));

        if ($acceptance->current_reviewer_role) {
            $this->notifyRole($acceptance, $acceptance->current_reviewer_role, '收到待审验收', '项目“'.$acceptance->project->title.'”已流转到你的验收审核阶段。');
        }

        return response()->json([
            'review' => $review,
            'acceptance' => $acceptance->refresh()->load('project.unit'),
        ], 201);
    }

    public function uploadFile(StoreProjectFileRequest $request, AcceptanceApplication $acceptance)
    {
        $this->authorizeUnitAcceptance($request, $acceptance);

        $uploaded = $request->file('file');
        $path = $uploaded->store('project-files/'.$acceptance->project_id);
        $file = ProjectFile::create([
            'project_id' => $acceptance->project_id,
            'uploaded_by' => $request->user()->id,
            'disk' => config('filesystems.default'),
            'path' => $path,
            'original_name' => $this->safeOriginalName($uploaded),
            'mime_type' => $uploaded->getMimeType(),
            'extension' => strtolower($uploaded->getClientOriginalExtension()),
            'size_bytes' => $uploaded->getSize(),
            'sha256' => hash_file('sha256', $uploaded->getRealPath()),
            'purpose' => 'acceptance',
            'metadata' => $request->input('metadata', []) + ['acceptance_id' => $acceptance->id],
        ]);

        $this->auditLogger->record($request, 'acceptance_file.uploaded', $file, ['acceptance_id' => $acceptance->id]);

        return response()->json($file, 201);
    }

    public function extension(Request $request, AcceptanceApplication $acceptance)
    {
        if ($request->user()->role === Role::UNIT) {
            $this->authorizeUnitAcceptance($request, $acceptance);

            $data = $request->validate([
                'reason' => ['required', 'string', 'max:3000'],
                'expected_date' => ['nullable', 'date'],
            ]);

            $extension = AcceptanceExtension::create($data + [
                'acceptance_application_id' => $acceptance->id,
                'project_id' => $acceptance->project_id,
                'requested_by' => $request->user()->id,
                'status' => 'pending',
            ]);

            $this->auditLogger->record($request, 'acceptance.extension_requested', $extension);
            $this->notifyRole($acceptance, Role::ADMIN, '收到验收延期申请', '项目“'.$acceptance->project->title.'”收到验收延期申请。');

            return response()->json($extension, 201);
        }

        if (! Role::userCan($request->user(), 'manage_acceptance')) {
            abort(403, '无权处理延期申请');
        }

        $data = $request->validate([
            'extension_id' => ['required', 'integer', 'exists:acceptance_extensions,id'],
            'decision' => ['required', 'in:approved,rejected'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $extension = AcceptanceExtension::query()
            ->where('acceptance_application_id', $acceptance->id)
            ->findOrFail($data['extension_id']);

        $extension->update([
            'status' => $data['decision'],
            'review_comment' => $data['comment'] ?? null,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        $this->auditLogger->record($request, 'acceptance.extension_reviewed', $extension, ['decision' => $data['decision']]);
        $this->notifyOwner($acceptance, '验收延期申请已处理', '处理结果：'.$data['decision'].'。'.($data['comment'] ?? ''));

        return $extension->refresh();
    }

    private function canView(Request $request): bool
    {
        return Role::userCan($request->user(), 'submit_acceptance')
            || Role::userCan($request->user(), 'manage_acceptance')
            || Role::userCan($request->user(), 'review_acceptance');
    }

    private function acceptanceTimeline(AcceptanceApplication $acceptance): array
    {
        $acceptance->loadMissing(['submitter', 'reviews.reviewer']);
        $reviews = $acceptance->reviews->keyBy('stage');

        $stages = [
            ['key' => 'submitted', 'label' => '单位提交', 'role' => Role::UNIT],
            ['key' => Role::COUNTY, 'label' => '区县审核', 'role' => Role::COUNTY],
            ['key' => Role::DEPARTMENT, 'label' => '部门审核', 'role' => Role::DEPARTMENT],
            ['key' => Role::EXPERT, 'label' => '专家评审', 'role' => Role::EXPERT],
            ['key' => Role::ADMIN, 'label' => '科技局终审关闭', 'role' => Role::ADMIN],
        ];

        return collect($stages)->map(function (array $stage) use ($acceptance, $reviews): array {
            if ($stage['key'] === 'submitted') {
                return [
                    ...$stage,
                    'status' => $acceptance->submitted_at ? 'done' : 'pending',
                    'handler' => $acceptance->submitter?->name ?: $acceptance->submitter?->username,
                    'handled_at' => $acceptance->submitted_at?->toDateTimeString(),
                    'decision' => $acceptance->submitted_at ? 'submitted' : null,
                    'comment' => $acceptance->summary,
                ];
            }

            $review = $reviews->get($stage['key']);

            return [
                ...$stage,
                'status' => $review ? 'done' : ($acceptance->current_reviewer_role === $stage['key'] ? 'current' : 'pending'),
                'handler' => $review?->reviewer?->name ?: $review?->reviewer?->username,
                'handled_at' => $review?->reviewed_at?->toDateTimeString(),
                'decision' => $review?->decision,
                'score' => $review?->score,
                'comment' => $review?->comment,
            ];
        })->all();
    }

    private function authorizeAccess(Request $request, AcceptanceApplication $acceptance): void
    {
        if (! $this->canView($request)) {
            abort(403, '无权查看验收');
        }

        if ($request->user()->role === Role::UNIT && $acceptance->unit_id !== $request->user()->unit_id) {
            abort(403, '无权查看该验收');
        }
    }

    private function authorizeUnitProject(Request $request, Project $project): void
    {
        if ($request->user()->role !== Role::UNIT || $project->unit_id !== $request->user()->unit_id) {
            abort(403, '只有项目所属单位可以维护验收');
        }

        if ($request->user()->loadMissing('unit')->unit?->status !== 'active') {
            abort(403, '单位已停用，无法维护验收');
        }
    }

    private function authorizeUnitAcceptance(Request $request, AcceptanceApplication $acceptance): void
    {
        $this->authorizeUnitProject($request, $acceptance->project);
    }

    private function authorizeReview(Request $request, AcceptanceApplication $acceptance): void
    {
        if (! Role::userCan($request->user(), 'review_acceptance') && ! Role::userCan($request->user(), 'manage_acceptance')) {
            abort(403, '无权处理验收审核');
        }

        $stage = Role::reviewerStageFor($request->user()->role);
        if ($acceptance->current_reviewer_role !== $stage) {
            abort(403, '当前验收不属于你的审核阶段');
        }
    }

    private function nextAcceptanceState(AcceptanceApplication $acceptance, string $decision): array
    {
        if ($decision === 'return') {
            return ['status' => AcceptanceApplication::STATUS_RETURNED, 'current_reviewer_role' => null];
        }

        if ($decision === 'reject') {
            return ['status' => AcceptanceApplication::STATUS_REJECTED, 'current_reviewer_role' => null];
        }

        $flow = [Role::COUNTY => Role::DEPARTMENT, Role::DEPARTMENT => Role::EXPERT, Role::EXPERT => Role::ADMIN];
        $nextRole = $flow[$acceptance->current_reviewer_role] ?? null;

        if ($nextRole) {
            return ['status' => AcceptanceApplication::STATUS_REVIEWING, 'current_reviewer_role' => $nextRole];
        }

        return [
            'status' => $decision === 'close' ? AcceptanceApplication::STATUS_CLOSED : AcceptanceApplication::STATUS_APPROVED,
            'current_reviewer_role' => null,
            'closed_at' => now(),
        ];
    }

    private function notifyOwner(AcceptanceApplication $acceptance, string $title, string $body): void
    {
        Message::create([
            'recipient_id' => $acceptance->project->owner_id,
            'project_id' => $acceptance->project_id,
            'type' => 'acceptance',
            'title' => $title,
            'body' => $body,
        ]);
    }

    private function notifyRole(AcceptanceApplication $acceptance, string $role, string $title, string $body): void
    {
        User::query()
            ->where(function ($query) use ($role): void {
                $query->where('role', $role);
                if ($role === Role::ADMIN) {
                    $query->orWhere('role', Role::SUPER_ADMIN);
                }
            })
            ->where('is_active', true)
            ->each(function (User $user) use ($acceptance, $title, $body): void {
                Message::create([
                    'recipient_id' => $user->id,
                    'project_id' => $acceptance->project_id,
                    'type' => 'acceptance',
                    'title' => $title,
                    'body' => $body,
                ]);
            });
    }

    private function safeOriginalName(UploadedFile $file): string
    {
        $name = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $file->getClientOriginalName()) ?? '';
        $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '');

        return $name !== '' ? $name : 'attachment.'.$file->getClientOriginalExtension();
    }
}
