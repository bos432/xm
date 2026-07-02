<?php

namespace App\Http\Controllers;

use App\Models\ExpertCertification;
use App\Models\Project;
use App\Models\ProjectProgressRecord;
use App\Models\ProjectRectification;
use App\Models\ProjectTaskBook;
use App\Support\AuditLogger;
use App\Support\RichTextSanitizer;
use App\Support\Role;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

class ProjectLifecycleController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function taskBooks(Request $request)
    {
        $this->authorizePermission($request, 'view_task_books');

        return $this->projectScoped(ProjectTaskBook::query(), $request)
            ->with(['project.unit', 'project.applicationBatch', 'unit', 'submitter', 'reviewer'])
            ->latest()
            ->paginate(20);
    }

    public function storeTaskBook(Request $request, Project $project)
    {
        $this->authorizeUnitProject($request, $project, 'create_task_books');

        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'content' => ['nullable', 'string', 'max:20000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['content']);

        $taskBook = ProjectTaskBook::create($data + [
            'project_id' => $project->id,
            'unit_id' => $project->unit_id,
            'submitted_by' => $request->user()->id,
            'status' => 'draft',
        ]);

        $this->auditLogger->record($request, 'task_book.created', $taskBook, ['project_id' => $project->id]);

        return response()->json($taskBook->load(['project.unit', 'unit']), 201);
    }

    public function updateTaskBook(Request $request, ProjectTaskBook $taskBook)
    {
        $this->authorizeUnitProject($request, $taskBook->project, 'update_task_books');

        if (! in_array($taskBook->status, ['draft', 'returned'], true)) {
            return response()->json(['message' => '当前状态不允许修改任务书'], 422);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'content' => ['nullable', 'string', 'max:20000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['content']);

        $taskBook->update($data);
        $this->auditLogger->record($request, 'task_book.updated', $taskBook, ['project_id' => $taskBook->project_id]);

        return $taskBook->refresh()->load(['project.unit', 'unit']);
    }

    public function submitTaskBook(Request $request, ProjectTaskBook $taskBook)
    {
        $this->authorizeUnitProject($request, $taskBook->project, 'submit_task_books');

        if (! in_array($taskBook->status, ['draft', 'returned'], true)) {
            return response()->json(['message' => '当前状态不允许提交任务书'], 422);
        }

        $taskBook->update(['status' => 'submitted', 'submitted_at' => now()]);
        $this->auditLogger->record($request, 'task_book.submitted', $taskBook, ['project_id' => $taskBook->project_id]);

        return $taskBook->refresh()->load(['project.unit', 'unit']);
    }

    public function reviewTaskBook(Request $request, ProjectTaskBook $taskBook)
    {
        $this->authorizePermission($request, 'review_task_books');
        $this->ensureSubmittedForReview($taskBook->status);

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $taskBook->update($this->reviewPayload($request, $data));
        $this->auditLogger->record($request, 'task_book.reviewed', $taskBook, [
            'project_id' => $taskBook->project_id,
            'decision' => $data['decision'],
        ]);

        return $taskBook->refresh()->load(['project.unit', 'unit', 'reviewer']);
    }

    public function progress(Request $request)
    {
        $this->authorizePermission($request, 'view_project_progress');

        return $this->projectScoped(ProjectProgressRecord::query(), $request, false)
            ->with(['project.unit', 'project.applicationBatch', 'unit', 'submitter', 'reviewer'])
            ->latest()
            ->paginate(20);
    }

    public function storeProgress(Request $request, Project $project)
    {
        $this->authorizeUnitProject($request, $project, 'create_project_progress');

        $data = $request->validate([
            'period' => ['nullable', 'string', 'max:120'],
            'progress_date' => ['nullable', 'date'],
            'summary' => ['required', 'string', 'max:20000'],
            'issues' => ['nullable', 'string', 'max:10000'],
            'next_plan' => ['nullable', 'string', 'max:10000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['summary', 'issues', 'next_plan']);

        $record = ProjectProgressRecord::create($data + [
            'project_id' => $project->id,
            'unit_id' => $project->unit_id,
            'submitted_by' => $request->user()->id,
            'status' => 'draft',
        ]);

        $this->auditLogger->record($request, 'project_progress.created', $record, ['project_id' => $project->id]);

        return response()->json($record->load(['project.unit', 'unit']), 201);
    }

    public function updateProgress(Request $request, ProjectProgressRecord $progress)
    {
        $this->authorizeUnitProject($request, $progress->project, 'update_project_progress');

        if (! in_array($progress->status, ['draft', 'returned'], true)) {
            return response()->json(['message' => '当前状态不允许修改进展记录'], 422);
        }

        $data = $request->validate([
            'period' => ['nullable', 'string', 'max:120'],
            'progress_date' => ['nullable', 'date'],
            'summary' => ['required', 'string', 'max:20000'],
            'issues' => ['nullable', 'string', 'max:10000'],
            'next_plan' => ['nullable', 'string', 'max:10000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['summary', 'issues', 'next_plan']);

        $progress->update($data);
        $this->auditLogger->record($request, 'project_progress.updated', $progress, ['project_id' => $progress->project_id]);

        return $progress->refresh()->load(['project.unit', 'unit']);
    }

    public function submitProgress(Request $request, ProjectProgressRecord $progress)
    {
        $this->authorizeUnitProject($request, $progress->project, 'submit_project_progress');

        if (! in_array($progress->status, ['draft', 'returned'], true)) {
            return response()->json(['message' => '当前状态不允许提交进展记录'], 422);
        }

        $progress->update(['status' => 'submitted', 'submitted_at' => now()]);
        $this->auditLogger->record($request, 'project_progress.submitted', $progress, ['project_id' => $progress->project_id]);

        return $progress->refresh()->load(['project.unit', 'unit']);
    }

    public function reviewProgress(Request $request, ProjectProgressRecord $progress)
    {
        $this->authorizePermission($request, 'review_project_progress');
        $this->ensureSubmittedForReview($progress->status);

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $progress->update($this->reviewPayload($request, $data));
        $this->auditLogger->record($request, 'project_progress.reviewed', $progress, [
            'project_id' => $progress->project_id,
            'decision' => $data['decision'],
        ]);

        return $progress->refresh()->load(['project.unit', 'unit', 'reviewer']);
    }

    public function rectifications(Request $request)
    {
        $this->authorizePermission($request, 'view_rectifications');

        return $this->projectScoped(ProjectRectification::query(), $request)
            ->with(['project.unit', 'project.applicationBatch', 'unit', 'creator', 'submitter', 'reviewer'])
            ->latest()
            ->paginate(20);
    }

    public function storeRectification(Request $request, Project $project)
    {
        $this->authorizePermission($request, 'create_rectifications');

        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'requirement' => ['nullable', 'string', 'max:20000'],
            'due_date' => ['nullable', 'date'],
        ]);
        $data = $this->cleanRichTextFields($data, ['requirement']);

        $rectification = ProjectRectification::create($data + [
            'project_id' => $project->id,
            'unit_id' => $project->unit_id,
            'created_by' => $request->user()->id,
            'status' => 'pending',
        ]);

        $this->auditLogger->record($request, 'rectification.created', $rectification, ['project_id' => $project->id]);

        return response()->json($rectification->load(['project.unit', 'unit']), 201);
    }

    public function submitRectification(Request $request, ProjectRectification $rectification)
    {
        $this->authorizeUnitProject($request, $rectification->project, 'submit_rectifications');

        if (! in_array($rectification->status, ['pending', 'returned'], true)) {
            return response()->json(['message' => '当前状态不允许提交整改材料'], 422);
        }

        $data = $request->validate([
            'response' => ['required', 'string', 'max:20000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['response']);

        $rectification->update($data + [
            'status' => 'submitted',
            'submitted_by' => $request->user()->id,
            'submitted_at' => now(),
        ]);
        $this->auditLogger->record($request, 'rectification.submitted', $rectification, ['project_id' => $rectification->project_id]);

        return $rectification->refresh()->load(['project.unit', 'unit']);
    }

    public function reviewRectification(Request $request, ProjectRectification $rectification)
    {
        $this->authorizePermission($request, 'review_rectifications');
        $this->ensureSubmittedForReview($rectification->status);

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $rectification->update($this->reviewPayload($request, $data));
        $this->auditLogger->record($request, 'rectification.reviewed', $rectification, [
            'project_id' => $rectification->project_id,
            'decision' => $data['decision'],
        ]);

        return $rectification->refresh()->load(['project.unit', 'unit', 'reviewer']);
    }

    public function expertCertifications(Request $request)
    {
        $this->authorizePermission($request, 'view_expert_certifications');

        $query = ExpertCertification::query()->with(['user', 'submitter', 'reviewer'])->latest();
        if ($request->user()->role === Role::EXPERT) {
            $query->where('user_id', $request->user()->id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('keyword')) {
            $keyword = $request->query('keyword');
            $query->where(function (Builder $query) use ($keyword): void {
                $query->where('organization', 'like', "%{$keyword}%")
                    ->orWhere('specialty', 'like', "%{$keyword}%")
                    ->orWhere('professional_title', 'like', "%{$keyword}%")
                    ->orWhere('certificate_no', 'like', "%{$keyword}%")
                    ->orWhereHas('user', fn (Builder $query) => $query
                        ->where('username', 'like', "%{$keyword}%")
                        ->orWhere('name', 'like', "%{$keyword}%"));
            });
        }

        return $query->paginate(20);
    }

    public function storeExpertCertification(Request $request)
    {
        $this->authorizePermission($request, 'submit_expert_certifications');

        $data = $request->validate([
            'organization' => ['nullable', 'string', 'max:200'],
            'specialty' => ['required', 'string', 'max:200'],
            'professional_title' => ['nullable', 'string', 'max:160'],
            'certificate_no' => ['nullable', 'string', 'max:160'],
            'summary' => ['nullable', 'string', 'max:20000'],
        ]);
        $data = $this->cleanRichTextFields($data, ['summary']);

        $certification = ExpertCertification::create($data + [
            'user_id' => $request->user()->id,
            'submitted_by' => $request->user()->id,
            'status' => 'submitted',
            'submitted_at' => now(),
        ]);

        $this->auditLogger->record($request, 'expert_certification.submitted', $certification);

        return response()->json($certification->load(['user', 'submitter']), 201);
    }

    public function reviewExpertCertification(Request $request, ExpertCertification $certification)
    {
        $this->authorizePermission($request, 'review_expert_certifications');
        $this->ensureSubmittedForReview($certification->status);

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject'],
            'comment' => ['nullable', 'string', 'max:3000'],
        ]);

        $certification->update($this->reviewPayload($request, $data));
        $this->auditLogger->record($request, 'expert_certification.reviewed', $certification, [
            'decision' => $data['decision'],
        ]);

        return $certification->refresh()->load(['user', 'reviewer']);
    }

    private function projectScoped(Builder $query, Request $request, bool $hasTitle = true): Builder
    {
        if ($request->user()->role === Role::UNIT) {
            $query->where('unit_id', $request->user()->unit_id);
        }

        if ($request->filled('project_id')) {
            $query->where('project_id', $request->query('project_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('unit_id') && in_array($request->user()->role, Role::adminRoles(), true)) {
            $query->where('unit_id', $request->query('unit_id'));
        }

        if ($request->filled('batch_id')) {
            $query->whereHas('project', fn (Builder $query) => $query
                ->where('application_batch_id', $request->query('batch_id')));
        }

        if ($request->filled('project_status')) {
            $query->whereHas('project', fn (Builder $query) => $query
                ->where('status', $request->query('project_status')));
        }

        if ($request->filled('keyword')) {
            $keyword = $request->query('keyword');
            $query->where(function (Builder $query) use ($keyword, $hasTitle): void {
                if ($hasTitle) {
                    $query->where('title', 'like', "%{$keyword}%")
                        ->orWhereHas('project', fn (Builder $query) => $query
                            ->where('title', 'like', "%{$keyword}%")
                            ->orWhere('legacy_id', 'like', "%{$keyword}%")
                            ->orWhereHas('applicationBatch', fn (Builder $query) => $query
                                ->where('name', 'like', "%{$keyword}%")
                                ->orWhere('code', 'like', "%{$keyword}%")))
                        ->orWhereHas('unit', fn (Builder $query) => $query->where('name', 'like', "%{$keyword}%"));

                    return;
                }

                $query->where('summary', 'like', "%{$keyword}%")
                    ->orWhere('period', 'like', "%{$keyword}%")
                    ->orWhereHas('project', fn (Builder $query) => $query
                        ->where('title', 'like', "%{$keyword}%")
                        ->orWhere('legacy_id', 'like', "%{$keyword}%")
                        ->orWhereHas('applicationBatch', fn (Builder $query) => $query
                            ->where('name', 'like', "%{$keyword}%")
                            ->orWhere('code', 'like', "%{$keyword}%")))
                    ->orWhereHas('unit', fn (Builder $query) => $query->where('name', 'like', "%{$keyword}%"));
            });
        }

        return $query;
    }

    private function reviewPayload(Request $request, array $data): array
    {
        $comment = RichTextSanitizer::clean($data['comment'] ?? null);

        return [
            'status' => match ($data['decision']) {
                'approve' => 'approved',
                'return' => 'returned',
                'reject' => 'rejected',
            },
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_comment' => $comment,
        ];
    }

    private function cleanRichTextFields(array $data, array $fields): array
    {
        foreach ($fields as $field) {
            if (array_key_exists($field, $data)) {
                $data[$field] = RichTextSanitizer::clean($data[$field] ?? null);
            }
        }

        return $data;
    }

    private function ensureSubmittedForReview(string $status): void
    {
        if ($status !== 'submitted') {
            abort(422, '当前状态不允许审核');
        }
    }

    private function authorizePermission(Request $request, string $permission): void
    {
        if (! Role::userCan($request->user(), $permission)) {
            abort(403, '无权访问该全周期功能');
        }
    }

    private function authorizeUnitProject(Request $request, Project $project, string $permission): void
    {
        $this->authorizePermission($request, $permission);

        if ($request->user()->role !== Role::UNIT || $project->unit_id !== $request->user()->unit_id) {
            abort(403, '只有项目所属单位可以处理该事项');
        }

        if ($request->user()->loadMissing('unit')->unit?->status !== 'active') {
            abort(403, '单位已停用，无法处理该事项');
        }
    }
}
