<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProjectRequest;
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
        if (! in_array('view_projects', Role::capabilities($request->user()->role), true)) {
            abort(403, '无权访问项目');
        }

        $query = Project::query()->with(['unit', 'owner']);

        if ($request->user()->role === Role::UNIT) {
            $query->where('unit_id', $request->user()->unit_id);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($category = $request->query('category')) {
            $query->where('category', $category);
        }

        if ($projectType = $request->query('project_type')) {
            $query->where('project_type', $projectType);
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

        return $query->latest()
            ->paginate(20)
            ->through(function (Project $project) {
                $project->pending_extension_requests_count = $project->pendingExtensionRequestsCount();

                return $project;
            });
    }

    public function store(StoreProjectRequest $request)
    {
        $this->authorizeUnitApplicant($request);

        $user = $request->user();
        $project = Project::create($request->validated() + [
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

        return $project->load([
            'unit', 'owner',
            'files' => fn ($q) => $q->latest(),
            'reviews' => fn ($q) => $q->with('reviewer')->latest('reviewed_at'),
        ]);
    }

    public function update(StoreProjectRequest $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        if (! in_array($project->status, [Project::STATUS_DRAFT, Project::STATUS_RETURNED], true)) {
            return response()->json(['message' => '当前状态不允许修改'], 422);
        }

        $project->update($request->validated());

        $this->auditLogger->record($request, 'project.updated', $project);

        return $project->refresh()->load(['unit', 'owner']);
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
            ->where('role', $role)
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
        if ($request->user()->role !== Role::ADMIN) {
            abort(403, '只有管理员可以处理项目验收');
        }
    }

    private function authorizeProjectAccess(Request $request, Project $project): void
    {
        $user = $request->user();

        if (! in_array('view_projects', Role::capabilities($user->role), true)) {
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
}
