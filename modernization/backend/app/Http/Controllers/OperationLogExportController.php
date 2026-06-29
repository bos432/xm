<?php

namespace App\Http\Controllers;

use App\Models\OperationLog;
use App\Support\AuditLogger;
use App\Support\CsvExport;
use App\Support\Role;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class OperationLogExportController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function csv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'view_operation_logs')) {
            abort(403, '无权导出操作日志');
        }

        $query = OperationLog::query()->with('user:id,name,username,role')->latest();

        if ($action = $request->query('action')) {
            $query->where('action', $action);
        }

        if ($targetType = $request->query('target_type')) {
            $query->where('target_type', $targetType);
        }

        if ($request->filled('target_id')) {
            $query->where('target_id', $request->query('target_id'));
        }

        if ($ipAddress = $request->query('ip_address')) {
            $query->where('ip_address', $ipAddress);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('action', 'like', '%'.$keyword.'%')
                    ->orWhere('user_agent', 'like', '%'.$keyword.'%')
                    ->orWhere('payload', 'like', '%'.$keyword.'%')
                    ->orWhereHas('user', function ($query) use ($keyword): void {
                        $query->where('username', 'like', '%'.$keyword.'%')
                            ->orWhere('name', 'like', '%'.$keyword.'%');
                    });
            });
        }

        if ($dateFrom = $request->query('date_from')) {
            $query->whereDate('created_at', '>=', $dateFrom);
        }

        if ($dateTo = $request->query('date_to')) {
            $query->whereDate('created_at', '<=', $dateTo);
        }

        $logs = $query->get();

        $this->auditLogger->record($request, 'operation_log.exported', null, [
            'format' => 'csv',
            'action' => $request->query('action'),
            'target_type' => $request->query('target_type'),
            'target_id' => $request->query('target_id'),
            'ip_address' => $request->query('ip_address'),
            'keyword' => $request->query('keyword'),
            'date_from' => $request->query('date_from'),
            'date_to' => $request->query('date_to'),
            'count' => $logs->count(),
        ]);

        $filename = 'operation-logs-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($logs): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            CsvExport::writeRow($output, ['日志ID', '动作', '账号', '角色', '对象类型', '对象ID', 'IP', 'User Agent', '载荷', '时间']);

            foreach ($logs as $log) {
                CsvExport::writeRow($output, [
                    $log->id,
                    $log->action,
                    $log->user?->username,
                    $log->user?->role,
                    $log->target_type,
                    $log->target_id,
                    $log->ip_address,
                    $log->user_agent,
                    $log->payload ? json_encode($log->payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
                    optional($log->created_at)->format('Y-m-d H:i:s'),
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
