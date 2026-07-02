<?php

namespace App\Http\Controllers;

use App\Models\SystemSetting;
use App\Support\AuditLogger;
use App\Support\MailCenter;
use App\Support\Role;
use App\Support\RuntimeConfig;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class SystemSettingController extends Controller
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MailCenter $mailCenter,
    )
    {
    }

    public function index(Request $request)
    {
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
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
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
            abort(403, '无权查看系统配置');
        }

        RuntimeConfig::applyMailSettings();
        $smtp = config('mail.mailers.smtp', []);
        $mailer = (string) config('mail.default', 'log');
        $databaseFrom = trim((string) RuntimeConfig::value('mail.from_address', ''));

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
                'from_source' => $databaseFrom !== '' ? 'database' : 'env',
                'app_url' => (string) config('app.url'),
            ],
            'queue' => [
                'driver' => (string) config('queue.default', 'sync'),
                'pending_jobs' => DB::table('jobs')->count(),
                'failed_jobs' => DB::table('failed_jobs')->count(),
                'worker_hint' => 'php artisan queue:work --queue=default --tries=3 --timeout=90',
            ],
            'paths' => [
                'env' => '/www/wwwroot/nxm.zlck888.com/shared/.env',
                'homepage' => '/public-home',
            ],
        ]);
    }

    public function groups(Request $request)
    {
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
            abort(403, '只有超级管理员可以查看系统配置');
        }

        return response()->json([
            'groups' => collect($this->groupDefinitions())
                ->map(fn (array $group) => [
                    'key' => $group['key'],
                    'title' => $group['title'],
                    'description' => $group['description'],
                    'fields' => collect($group['fields'])
                        ->map(fn (array $field) => $this->fieldPayload($field, $group['key']))
                        ->values()
                        ->all(),
                ])
                ->values()
                ->all(),
            'runtime' => [
                'app_url' => config('app.url'),
                'queue_driver' => config('queue.default', 'sync'),
                'pending_jobs' => DB::table('jobs')->count(),
                'failed_jobs' => DB::table('failed_jobs')->count(),
            ],
        ]);
    }

    public function updateGroup(Request $request, string $group)
    {
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
            abort(403, '只有超级管理员可以修改系统配置');
        }

        $definition = collect($this->groupDefinitions())->firstWhere('key', $group);
        if (! $definition) {
            abort(404, '配置分组不存在');
        }

        $data = $request->validate([
            'values' => ['required', 'array'],
        ]);

        foreach ($definition['fields'] as $field) {
            $key = $field['key'];
            if (! array_key_exists($key, $data['values'])) {
                continue;
            }

            $value = $data['values'][$key];
            $setting = SystemSetting::query()->where('key', $key)->first();
            if (($field['secret'] ?? false) && blank($value) && $setting) {
                continue;
            }

            RuntimeConfig::set(
                $key,
                is_bool($value) ? ($value ? '1' : '0') : (string) $value,
                $group,
                (bool) ($field['secret'] ?? false),
                $field['description'] ?? $field['label']
            );
        }

        $this->auditLogger->record($request, 'settings.group_updated', null, ['group' => $group]);

        return $this->groups($request);
    }

    public function testMail(Request $request)
    {
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
            abort(403, '只有超级管理员可以发送测试邮件');
        }

        $data = $request->validate([
            'to' => ['required', 'email', 'max:255'],
        ]);

        $log = $this->mailCenter->queueTemplate('test_mail', $data['to'], [
            'sent_at' => now()->toDateTimeString(),
        ], $request->user(), $request->user()->name);

        $this->auditLogger->record($request, 'settings.mail_test_queued', $log, ['to' => $data['to']]);

        return response()->json($log, 202);
    }

    public function update(Request $request, SystemSetting $setting)
    {
        if (! Role::canManageSensitiveSettings($request->user()->role)) {
            abort(403, '无权修改系统配置');
        }

        $data = $request->validate([
            'value' => [$setting->is_secret ? 'nullable' : 'required', 'string', 'max:5000'],
            'description' => ['nullable', 'string', 'max:500'],
        ]);

        if ($setting->is_secret) {
            if (blank($data['value'] ?? null)) {
                unset($data['value']);
            } else {
                $data['value'] = Crypt::encryptString($data['value']);
            }
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
            $setting->value = RuntimeConfig::maskedSettingValue($setting);
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

    private function fieldPayload(array $field, string $group): array
    {
        $setting = SystemSetting::query()->where('key', $field['key'])->first();

        return [
            ...$field,
            'group' => $group,
            'value' => $setting
                ? ($setting->is_secret ? RuntimeConfig::maskedSettingValue($setting) : (string) $setting->value)
                : (string) ($field['default'] ?? ''),
            'configured' => $setting && filled($setting->value),
        ];
    }

    private function groupDefinitions(): array
    {
        return [
            [
                'key' => 'site',
                'title' => '站点信息',
                'description' => '系统名称、后台副标题、首页版权和展示 URL。',
                'fields' => [
                    ['key' => 'site.name', 'label' => '系统名称', 'type' => 'text', 'default' => '阿拉善盟科技计划项目管理信息系统'],
                    ['key' => 'site.admin_subtitle', 'label' => '后台副标题', 'type' => 'text', 'default' => '科技项目管理后台'],
                    ['key' => 'site.footer_text', 'label' => '首页版权/备案文字', 'type' => 'textarea', 'default' => '阿拉善盟科技计划项目管理信息系统 版权所有'],
                    ['key' => 'site.app_url_display', 'label' => 'APP_URL 展示值', 'type' => 'text', 'default' => config('app.url')],
                ],
            ],
            [
                'key' => 'mail',
                'title' => '邮件 SMTP',
                'description' => '找回密码、注册审核和流程提醒使用这里的运行时邮件配置。',
                'fields' => [
                    ['key' => 'mail.mailer', 'label' => 'Mailer', 'type' => 'select', 'default' => 'log', 'options' => ['smtp', 'log', 'array']],
                    ['key' => 'mail.host', 'label' => 'SMTP 主机', 'type' => 'text', 'default' => ''],
                    ['key' => 'mail.port', 'label' => 'SMTP 端口', 'type' => 'number', 'default' => '465'],
                    ['key' => 'mail.encryption', 'label' => '加密方式', 'type' => 'select', 'default' => 'ssl', 'options' => ['ssl', 'tls', '']],
                    ['key' => 'mail.username', 'label' => 'SMTP 用户名', 'type' => 'text', 'default' => ''],
                    ['key' => 'mail.password', 'label' => 'SMTP 密码/授权码', 'type' => 'password', 'default' => '', 'secret' => true],
                    ['key' => 'mail.from_address', 'label' => '发件邮箱', 'type' => 'text', 'default' => ''],
                    ['key' => 'mail.from_name', 'label' => '发件人名称', 'type' => 'text', 'default' => '阿拉善盟科技计划项目管理信息系统'],
                ],
            ],
            [
                'key' => 'upload',
                'title' => '上传策略',
                'description' => '配置通用上传白名单、大小和危险扩展名黑名单。',
                'fields' => [
                    ['key' => 'upload.allowed_extensions', 'label' => '允许扩展名', 'type' => 'textarea', 'default' => config('modernization.upload_allowed_extensions')],
                    ['key' => 'upload.max_kb', 'label' => '最大大小 KB', 'type' => 'number', 'default' => (string) config('modernization.upload_max_kb')],
                    ['key' => 'upload.blocked_extensions', 'label' => '危险扩展名', 'type' => 'textarea', 'default' => config('modernization.upload_blocked_extensions')],
                ],
            ],
            [
                'key' => 'security',
                'title' => '安全策略',
                'description' => '登录失败锁定、IP 黑白名单开关等运行策略。',
                'fields' => [
                    ['key' => 'security.login_failure_threshold', 'label' => '失败阈值', 'type' => 'number', 'default' => '5'],
                    ['key' => 'security.lock_minutes', 'label' => '锁定分钟数', 'type' => 'number', 'default' => '30'],
                    ['key' => 'security.ip_whitelist_enabled', 'label' => '启用 IP 白名单', 'type' => 'boolean', 'default' => '0'],
                    ['key' => 'security.ip_blacklist_enabled', 'label' => '启用 IP 黑名单', 'type' => 'boolean', 'default' => '1'],
                ],
            ],
        ];
    }
}
