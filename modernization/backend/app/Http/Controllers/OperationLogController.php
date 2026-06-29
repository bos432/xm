<?php

namespace App\Http\Controllers;

use App\Models\OperationLog;
use App\Support\Role;
use Illuminate\Http\Request;

class OperationLogController extends Controller
{
    public function index(Request $request)
    {
        if (! Role::userCan($request->user(), 'view_operation_logs')) {
            abort(403, '无权查看操作日志');
        }

        $query = OperationLog::query()->with('user:id,name,username,role');

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

        return $query->latest()->paginate(30);
    }
}
