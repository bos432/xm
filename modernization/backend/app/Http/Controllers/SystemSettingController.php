<?php

namespace App\Http\Controllers;

use App\Models\SystemSetting;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;

class SystemSettingController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        if (! Role::canManageSettings($request->user()->role)) {
            abort(403, '无权查看系统配置');
        }

        return SystemSetting::query()
            ->select(['id', 'key', 'value', 'group', 'is_secret', 'description'])
            ->orderBy('group')
            ->orderBy('key')
            ->get()
            ->map(fn (SystemSetting $setting) => $this->maskSecretValue($setting));
    }

    public function update(Request $request, SystemSetting $setting)
    {
        if (! Role::canManageSettings($request->user()->role)) {
            abort(403, '无权修改系统配置');
        }

        $data = $request->validate([
            'value' => ['required', 'string', 'max:5000'],
            'description' => ['nullable', 'string', 'max:500'],
        ]);

        if ($setting->is_secret && $data['value'] === '') {
            unset($data['value']);
        }

        $setting->update($data);

        $this->auditLogger->record($request, 'setting.updated', $setting, [
            'key' => $setting->key,
            'group' => $setting->group,
            'is_secret' => $setting->is_secret,
        ]);

        return $this->maskSecretValue($setting->refresh());
    }

    private function maskSecretValue(SystemSetting $setting): SystemSetting
    {
        if ($setting->is_secret) {
            $setting->value = $setting->value ? '********' : '';
        }

        return $setting;
    }
}
