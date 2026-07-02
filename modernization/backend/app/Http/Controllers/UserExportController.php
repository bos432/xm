<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\AuditLogger;
use App\Support\CsvExport;
use App\Support\Role;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class UserExportController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function csv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'manage_users')) {
            abort(403, '无权导出账号');
        }

        $query = User::query()->with(['unit', 'additionalRoles']);

        if ($role = $request->query('role')) {
            $query->where('role', $role);
        }

        if ($request->has('is_active') && $request->query('is_active') !== '') {
            $query->where('is_active', $request->boolean('is_active'));
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('username', 'like', '%'.$keyword.'%')
                    ->orWhere('mobile', 'like', '%'.$keyword.'%')
                    ->orWhere('email', 'like', '%'.$keyword.'%');
            });
        }

        if ($request->boolean('pending_registration')) {
            $query->where('role', Role::UNIT)
                ->where('is_active', false)
                ->whereHas('unit', function ($query) {
                    $query->where('status', 'suspended')
                        ->where(function ($query) {
                            $query->where('metadata', 'like', '%"registration_status":"pending"%')
                                ->orWhere('metadata', 'like', '%"registration_status": "pending"%');
                        });
                });
        }

        $sortBy = $request->query('sort_by', 'created_at');
        $sortDirection = strtolower((string) $request->query('sort_direction', 'desc')) === 'asc' ? 'asc' : 'desc';
        $sortableColumns = ['created_at', 'last_login_at', 'username', 'name', 'role', 'is_active'];

        if (! in_array($sortBy, $sortableColumns, true)) {
            $sortBy = 'created_at';
        }

        $query->orderBy($sortBy, $sortDirection)
            ->orderBy('id', $sortDirection);

        $users = $query->get();

        $this->auditLogger->record($request, 'user.exported', null, [
            'format' => 'csv',
            'role' => $request->query('role'),
            'is_active' => $request->query('is_active'),
            'keyword' => $request->query('keyword'),
            'pending_registration' => $request->boolean('pending_registration'),
            'sort_by' => $sortBy,
            'sort_direction' => $sortDirection,
            'count' => $users->count(),
        ]);

        $filename = 'users-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($users): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            CsvExport::writeRow($output, ['账号ID', '账号', '姓名', '角色', '所属单位', '手机', '邮箱', '状态', '最后登录时间', '最后登录IP', '创建时间']);

            foreach ($users as $user) {
                CsvExport::writeRow($output, [
                    $user->id,
                    $user->username,
                    $user->name,
                    $user->role,
                    $user->unit?->name,
                    $user->mobile,
                    $user->email,
                    $user->is_active ? 'active' : 'inactive',
                    optional($user->last_login_at)->format('Y-m-d H:i:s'),
                    $user->last_login_ip,
                    optional($user->created_at)->format('Y-m-d H:i:s'),
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
