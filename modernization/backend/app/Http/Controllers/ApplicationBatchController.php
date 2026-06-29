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
        ]);
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_application_batches')) {
            abort(403, '无权维护申报批次');
        }
    }
}
