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
            ->where('key', '!=', 'public.homepage_content')
            ->orderBy('group')
            ->orderBy('key')
            ->get()
            ->map(fn (SystemSetting $setting) => $this->maskSecretValue($setting));
    }

    public function runtime(Request $request)
    {
        if (! Role::canManageSettings($request->user()->role)) {
            abort(403, '无权查看系统配置');
        }

        $smtp = config('mail.mailers.smtp', []);
        $mailer = (string) config('mail.default', 'log');
        $databaseFrom = trim((string) SystemSetting::query()
            ->where('key', 'mail.from_address')
            ->value('value'));

        return response()->json([
            'mail' => [
                'mailer' => $mailer,
                'is_smtp' => $mailer === 'smtp',
                'host' => (string) ($smtp['host'] ?? ''),
                'port' => (string) ($smtp['port'] ?? ''),
                'encryption' => (string) ($smtp['encryption'] ?? ''),
                'username' => $this->maskRuntimeValue((string) ($smtp['username'] ?? '')),
                'password_configured' => (string) ($smtp['password'] ?? '') !== '',
                'from_address' => $databaseFrom !== '' ? $databaseFrom : (string) config('mail.from.address'),
                'from_name' => (string) config('mail.from.name'),
                'from_source' => $databaseFrom !== '' ? 'system_setting' : 'env',
                'app_url' => (string) config('app.url'),
            ],
            'paths' => [
                'env' => '/www/wwwroot/nxm.zlck888.com/shared/.env',
                'homepage' => '/public-home',
            ],
        ]);
    }

    public function update(Request $request, SystemSetting $setting)
    {
        if (! Role::canManageSettings($request->user()->role)) {
            abort(403, '无权修改系统配置');
        }

        $data = $request->validate([
            'value' => [$setting->is_secret ? 'nullable' : 'required', 'string', 'max:5000'],
            'description' => ['nullable', 'string', 'max:500'],
        ]);

        if ($setting->is_secret && blank($data['value'] ?? null)) {
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

    private function maskRuntimeValue(string $value): string
    {
        if ($value === '') {
            return '';
        }

        if (strlen($value) <= 4) {
            return '****';
        }

        return substr($value, 0, 2).'****'.substr($value, -2);
    }
}
