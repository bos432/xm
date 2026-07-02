<?php

namespace App\Http\Controllers;

use App\Models\Project;
use App\Support\AuditLogger;
use App\Support\CsvExport;
use App\Support\Role;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ProjectExportController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function csv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'view_projects')) {
            abort(403, '无权导出项目');
        }

        $query = Project::query()
            ->with(['unit', 'owner', 'applicationBatch', 'reviews.reviewer'])
            ->orderBy('created_at')
            ->orderBy('id');

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

        if ($batchId = $request->query('application_batch_id')) {
            $query->where('application_batch_id', $batchId);
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

        $projects = $query->get();

        $this->auditLogger->record($request, 'project.exported', null, [
            'format' => 'csv',
            'status' => $request->query('status'),
            'category' => $request->query('category'),
            'project_type' => $request->query('project_type'),
            'application_batch_id' => $request->query('application_batch_id'),
            'pending_extension' => $request->boolean('pending_extension'),
            'keyword' => $request->query('keyword'),
            'count' => $projects->count(),
        ]);

        $filename = 'projects-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($projects): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            CsvExport::writeRow($output, [
                '项目ID',
                '项目名称',
                '申报单位',
                '申报批次',
                '计划类别',
                '项目类别',
                '项目类型',
                '归口管理单位',
                '归属区域',
                '状态',
                '待处理延期',
                '预算金额（元）',
                '是否推荐',
                '是否支持',
                '支持方式',
                '支持资金（万元）',
                '推荐专家',
                '提交时间',
                '负责人账号',
            ]);

            foreach ($projects as $project) {
                $metadata = is_array($project->metadata) ? $project->metadata : [];
                $finalSupport = $this->finalSupport($project);
                CsvExport::writeRow($output, [
                    $project->id,
                    $project->title,
                    $project->unit?->name,
                    $project->applicationBatch?->name,
                    $project->applicationBatch?->name ?: $project->category,
                    $project->category,
                    $project->project_type,
                    $metadata['management_unit'] ?? '',
                    $metadata['region_code'] ?? $project->unit?->region_code,
                    $project->status,
                    $project->pendingExtensionRequestsCount(),
                    $project->budget_amount,
                    $this->yesNo($finalSupport['is_recommended'] ?? null),
                    $this->yesNo($finalSupport['is_supported'] ?? null),
                    $this->supportTypeLabel($finalSupport['support_type'] ?? null),
                    $finalSupport['support_amount_wan'] ?? '',
                    $finalSupport['recommended_experts'] ?? $this->recommendedExpertNames($project),
                    optional($project->submitted_at)->format('Y-m-d H:i:s'),
                    $project->owner?->username,
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    private function finalSupport(Project $project): array
    {
        $metadata = is_array($project->metadata) ? $project->metadata : [];
        if (is_array($metadata['final_support'] ?? null)) {
            return $metadata['final_support'];
        }

        $review = $project->reviews
            ->where('stage', Role::ADMIN)
            ->where('decision', 'accept')
            ->sortByDesc('reviewed_at')
            ->first();

        $reviewMetadata = is_array($review?->metadata) ? $review->metadata : [];

        return is_array($reviewMetadata['final_support'] ?? null) ? $reviewMetadata['final_support'] : [];
    }

    private function recommendedExpertNames(Project $project): string
    {
        return $project->reviews
            ->where('stage', Role::EXPERT)
            ->where('decision', 'recommend')
            ->map(fn ($review): string => $review->reviewer?->name ?: $review->reviewer?->username ?: '')
            ->filter()
            ->unique()
            ->implode('、');
    }

    private function yesNo(mixed $value): string
    {
        if ($value === null || $value === '') {
            return '';
        }

        return filter_var($value, FILTER_VALIDATE_BOOLEAN) ? '是' : '否';
    }

    private function supportTypeLabel(?string $value): string
    {
        return match ($value) {
            'subsidy' => '补助支持',
            'interest' => '贴息支持',
            'other' => '其他支持',
            'none' => '不支持',
            default => '',
        };
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
