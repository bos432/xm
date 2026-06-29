<?php

namespace App\Http\Controllers;

use App\Models\Unit;
use App\Support\AuditLogger;
use App\Support\CsvExport;
use App\Support\Role;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class UnitExportController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function csv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'manage_units')) {
            abort(403, '无权导出单位资料');
        }

        $query = Unit::query()->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('credit_code', 'like', '%'.$keyword.'%')
                    ->orWhere('contact_name', 'like', '%'.$keyword.'%');
            });
        }

        if ($request->boolean('pending_registration')) {
            $query->where('status', 'suspended')
                ->where(function ($query) {
                    $query->where('metadata', 'like', '%"registration_status":"pending"%')
                        ->orWhere('metadata', 'like', '%"registration_status": "pending"%');
                });
        }

        $units = $query->get();

        $this->auditLogger->record($request, 'unit.exported', null, [
            'format' => 'csv',
            'status' => $request->query('status'),
            'keyword' => $request->query('keyword'),
            'pending_registration' => $request->boolean('pending_registration'),
            'count' => $units->count(),
        ]);

        $filename = 'units-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($units): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            CsvExport::writeRow($output, ['单位ID', '单位名称', '统一信用代码', '联系人', '联系电话', '邮箱', '区域编码', '状态', '地址']);

            foreach ($units as $unit) {
                CsvExport::writeRow($output, [
                    $unit->id,
                    $unit->name,
                    $unit->credit_code,
                    $unit->contact_name,
                    $unit->contact_mobile,
                    $unit->email,
                    $unit->region_code,
                    $unit->status,
                    $unit->address,
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
