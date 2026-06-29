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

        $query = Project::query()->with(['unit', 'owner', 'applicationBatch'])->latest();

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
            CsvExport::writeRow($output, ['项目ID', '项目名称', '申报单位', '申报批次', '项目类别', '项目类型', '状态', '待处理延期', '预算金额', '提交时间', '负责人账号']);

            foreach ($projects as $project) {
                CsvExport::writeRow($output, [
                    $project->id,
                    $project->title,
                    $project->unit?->name,
                    $project->applicationBatch?->name,
                    $project->category,
                    $project->project_type,
                    $project->status,
                    $project->pendingExtensionRequestsCount(),
                    $project->budget_amount,
                    optional($project->submitted_at)->format('Y-m-d H:i:s'),
                    $project->owner?->username,
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
