<?php

namespace App\Http\Controllers;

use App\Models\ApplicationBatch;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ApplicationBatchController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeManage($request);

        $query = ApplicationBatch::query()->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('code', 'like', '%'.$keyword.'%');
            });
        }

        if ($request->has('e2e')) {
            $request->boolean('e2e')
                ? $query->where(fn ($query) => $this->e2eBatchQuery($query))
                : $query->where(fn ($query) => $this->nonE2eBatchQuery($query));
        }

        return $query->paginate(20);
    }

    public function openBatches()
    {
        return ApplicationBatch::query()
            ->where('status', ApplicationBatch::STATUS_OPEN)
            ->where(function ($query): void {
                $query->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            })
            ->orderByDesc('starts_at')
            ->get();
    }

    public function store(Request $request)
    {
        $this->authorizeManage($request);

        $batch = ApplicationBatch::create($this->validatedData($request) + [
            'created_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'application_batch.created', $batch);

        return response()->json($batch, 201);
    }

    public function show(Request $request, ApplicationBatch $applicationBatch)
    {
        $this->authorizeManage($request);

        return $applicationBatch;
    }

    public function update(Request $request, ApplicationBatch $applicationBatch)
    {
        $this->authorizeManage($request);

        $applicationBatch->update($this->validatedData($request, $applicationBatch));
        $this->auditLogger->record($request, 'application_batch.updated', $applicationBatch);

        return $applicationBatch->refresh();
    }

    public function open(Request $request, ApplicationBatch $applicationBatch)
    {
        return $this->changeStatus($request, $applicationBatch, ApplicationBatch::STATUS_OPEN, 'application_batch.opened');
    }

    public function close(Request $request, ApplicationBatch $applicationBatch)
    {
        return $this->changeStatus($request, $applicationBatch, ApplicationBatch::STATUS_CLOSED, 'application_batch.closed');
    }

    public function archive(Request $request, ApplicationBatch $applicationBatch)
    {
        return $this->changeStatus($request, $applicationBatch, ApplicationBatch::STATUS_ARCHIVED, 'application_batch.archived');
    }

    public function archiveE2e(Request $request)
    {
        if ($request->user()->role !== Role::SUPER_ADMIN) {
            abort(403, '只有超级管理员可以批量归档测试批次');
        }

        $batches = ApplicationBatch::query()
            ->where(fn ($query) => $this->e2eBatchQuery($query))
            ->where('status', '!=', ApplicationBatch::STATUS_ARCHIVED)
            ->get();

        $batches->each(fn (ApplicationBatch $batch) => $batch->update(['status' => ApplicationBatch::STATUS_ARCHIVED]));

        $this->auditLogger->record($request, 'application_batch.e2e_archived', null, [
            'count' => $batches->count(),
            'batch_ids' => $batches->pluck('id')->all(),
        ]);

        return response()->json([
            'archived_count' => $batches->count(),
            'batch_ids' => $batches->pluck('id')->all(),
        ]);
    }

    private function changeStatus(Request $request, ApplicationBatch $batch, string $status, string $action)
    {
        $this->authorizeManage($request);

        $batch->update(['status' => $status]);
        $this->auditLogger->record($request, $action, $batch);

        return $batch->refresh();
    }

    private function validatedData(Request $request, ?ApplicationBatch $batch = null): array
    {
        $id = $batch?->id ?? 'NULL';

        return $request->validate([
            'name' => ['required', 'string', 'max:200'],
            'code' => ['required', 'string', 'max:80', 'unique:application_batches,code,'.$id],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after_or_equal:starts_at'],
            'status' => ['required', Rule::in([
                ApplicationBatch::STATUS_DRAFT,
                ApplicationBatch::STATUS_OPEN,
                ApplicationBatch::STATUS_CLOSED,
                ApplicationBatch::STATUS_ARCHIVED,
            ])],
            'allowed_categories' => ['nullable', 'array'],
            'allowed_project_types' => ['nullable', 'array'],
            'guide' => ['nullable', 'string'],
            'attachment_requirements' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'metadata.acceptance_required_materials' => ['nullable', 'array'],
            'metadata.acceptance_required_materials.*' => ['string', Rule::in([
                'acceptance_application',
                'project_summary',
                'financial',
                'achievement',
                'other',
            ])],
        ]);
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_application_batches')) {
            abort(403, '无权维护申报批次');
        }
    }

    private function e2eBatchQuery($query): void
    {
        $query->where('metadata', 'like', '%"e2e":true%')
            ->orWhere('metadata', 'like', '%"e2e": true%')
            ->orWhere('name', 'like', '%E2E-%')
            ->orWhere('code', 'like', '%E2E-%');
    }

    private function nonE2eBatchQuery($query): void
    {
        $query->where(function ($query): void {
            $query->whereNull('metadata')
                ->orWhere(function ($query): void {
                    $query->where('metadata', 'not like', '%"e2e":true%')
                        ->where('metadata', 'not like', '%"e2e": true%');
                });
        })
            ->where('name', 'not like', '%E2E-%')
            ->where('code', 'not like', '%E2E-%');
    }
}
