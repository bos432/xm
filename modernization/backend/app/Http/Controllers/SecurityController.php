<?php

namespace App\Http\Controllers;

use App\Models\SecurityEvent;
use App\Models\SecurityIpRule;
use App\Models\SecurityLock;
use App\Support\AuditLogger;
use App\Support\Role;
use App\Support\RuntimeConfig;
use Carbon\Carbon;
use Illuminate\Http\Request;

class SecurityController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function events(Request $request)
    {
        $this->authorizeManage($request);

        $query = SecurityEvent::query()->with('user:id,name,username,role')->latest();

        if ($type = $request->query('type')) {
            $query->where('type', $type);
        }

        if ($severity = $request->query('severity')) {
            $query->where('severity', $severity);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('username', 'like', '%'.$keyword.'%')
                    ->orWhere('ip_address', 'like', '%'.$keyword.'%')
                    ->orWhere('type', 'like', '%'.$keyword.'%');
            });
        }

        return $query->paginate(20);
    }

    public function blockedIdentities(Request $request)
    {
        $this->authorizeManage($request);

        return response()->json([
            'locks' => SecurityLock::query()->latest()->paginate(20),
            'ip_rules' => SecurityIpRule::query()->latest()->get(),
        ]);
    }

    public function storeBlockedIdentity(Request $request)
    {
        $this->authorizeManage($request);

        $data = $request->validate([
            'kind' => ['required', 'in:lock,ip_rule'],
            'identity_type' => ['required_if:kind,lock', 'nullable', 'in:username,ip'],
            'identity_value' => ['required_if:kind,lock', 'nullable', 'string', 'max:160'],
            'rule_type' => ['required_if:kind,ip_rule', 'nullable', 'in:blacklist,whitelist'],
            'cidr' => ['required_if:kind,ip_rule', 'nullable', 'string', 'max:80'],
            'description' => ['nullable', 'string', 'max:500'],
        ]);

        if ($data['kind'] === 'ip_rule') {
            $rule = SecurityIpRule::create([
                'type' => $data['rule_type'],
                'cidr' => $data['cidr'],
                'description' => $data['description'] ?? null,
                'created_by' => $request->user()->id,
            ]);
            $this->auditLogger->record($request, 'security.ip_rule_created', $rule);

            return response()->json($rule, 201);
        }

        $lock = SecurityLock::create([
            'identity_type' => $data['identity_type'],
            'identity_value' => $data['identity_value'],
            'failed_count' => 0,
            'reason' => $data['description'] ?? 'manual_lock',
            'is_active' => true,
            'locked_until' => null,
            'created_by' => $request->user()->id,
        ]);
        $this->auditLogger->record($request, 'security.lock_created', $lock);

        return response()->json($lock, 201);
    }

    public function destroyBlockedIdentity(Request $request, string $id)
    {
        $this->authorizeManage($request);

        if (str_starts_with($id, 'rule:')) {
            $rule = SecurityIpRule::query()->findOrFail((int) substr($id, 5));
            $rule->delete();
            $this->auditLogger->record($request, 'security.ip_rule_deleted', $rule);

            return response()->noContent();
        }

        $lock = SecurityLock::query()->findOrFail((int) $id);
        $lock->update(['is_active' => false, 'locked_until' => null]);
        $this->auditLogger->record($request, 'security.lock_released', $lock);

        return response()->noContent();
    }

    public function policies(Request $request)
    {
        $this->authorizeManage($request);

        $relaxedUntil = RuntimeConfig::value('security.login_throttle_relaxed_until');
        $relaxedConfigured = RuntimeConfig::boolValue('security.login_throttle_relaxed', false);
        $relaxedActive = $relaxedConfigured && $this->relaxedUntilIsActive($relaxedUntil);

        return response()->json([
            'login_failure_threshold' => RuntimeConfig::intValue('security.login_failure_threshold', 5),
            'lock_minutes' => RuntimeConfig::intValue('security.lock_minutes', 30),
            'ip_whitelist_enabled' => RuntimeConfig::boolValue('security.ip_whitelist_enabled', false),
            'ip_blacklist_enabled' => RuntimeConfig::boolValue('security.ip_blacklist_enabled', true),
            'login_throttle_per_minute' => RuntimeConfig::intValue('security.login_throttle_per_minute', 5),
            'login_throttle_relaxed' => $relaxedConfigured,
            'login_throttle_relaxed_active' => $relaxedActive,
            'login_throttle_relaxed_per_minute' => RuntimeConfig::intValue('security.login_throttle_relaxed_per_minute', 60),
            'login_throttle_whitelist_ips' => RuntimeConfig::value('security.login_throttle_whitelist_ips', '') ?? '',
            'login_throttle_relaxed_until' => $relaxedUntil,
            'login_throttle_relaxed_by' => RuntimeConfig::value('security.login_throttle_relaxed_by', '') ?? '',
            'login_throttle_relaxed_reason' => RuntimeConfig::value('security.login_throttle_relaxed_reason', '') ?? '',
        ]);
    }

    public function updatePolicies(Request $request)
    {
        $this->authorizeManage($request);

        $data = $request->validate([
            'login_failure_threshold' => ['required', 'integer', 'min:1', 'max:100'],
            'lock_minutes' => ['required', 'integer', 'min:1', 'max:1440'],
            'ip_whitelist_enabled' => ['required', 'boolean'],
            'ip_blacklist_enabled' => ['required', 'boolean'],
            'login_throttle_per_minute' => ['required', 'integer', 'min:1', 'max:300'],
            'login_throttle_relaxed' => ['required', 'boolean'],
            'login_throttle_relaxed_per_minute' => ['required', 'integer', 'min:1', 'max:1000'],
            'login_throttle_whitelist_ips' => ['nullable', 'string', 'max:2000'],
            'login_throttle_relaxed_until' => ['nullable', 'date'],
            'login_throttle_relaxed_reason' => ['nullable', 'string', 'max:500'],
        ]);

        RuntimeConfig::set('security.login_failure_threshold', (string) $data['login_failure_threshold'], 'security', false, '登录失败锁定阈值');
        RuntimeConfig::set('security.lock_minutes', (string) $data['lock_minutes'], 'security', false, '达到阈值后的锁定分钟数');
        RuntimeConfig::set('security.ip_whitelist_enabled', $data['ip_whitelist_enabled'] ? '1' : '0', 'security', false, '是否启用 IP 白名单');
        RuntimeConfig::set('security.ip_blacklist_enabled', $data['ip_blacklist_enabled'] ? '1' : '0', 'security', false, '是否启用 IP 黑名单');
        RuntimeConfig::set('security.login_throttle_per_minute', (string) $data['login_throttle_per_minute'], 'security', false, '登录接口每分钟限制');
        RuntimeConfig::set('security.login_throttle_relaxed', $data['login_throttle_relaxed'] ? '1' : '0', 'security', false, '是否临时放宽登录限流');
        RuntimeConfig::set('security.login_throttle_relaxed_per_minute', (string) $data['login_throttle_relaxed_per_minute'], 'security', false, '临时放宽后的每分钟限制');
        RuntimeConfig::set('security.login_throttle_whitelist_ips', $data['login_throttle_whitelist_ips'] ?? '', 'security', false, '登录限流测试白名单 IP');
        RuntimeConfig::set('security.login_throttle_relaxed_until', $data['login_throttle_relaxed_until'] ?? '', 'security', false, '登录限流临时放宽截止时间');
        RuntimeConfig::set('security.login_throttle_relaxed_by', $data['login_throttle_relaxed'] ? $request->user()->username : '', 'security', false, '登录限流临时放宽操作人');
        RuntimeConfig::set('security.login_throttle_relaxed_reason', $data['login_throttle_relaxed_reason'] ?? '', 'security', false, '登录限流临时放宽原因');
        $this->auditLogger->record($request, 'security.policies_updated', null, [
            'login_throttle_relaxed' => $data['login_throttle_relaxed'],
            'login_throttle_relaxed_until' => $data['login_throttle_relaxed_until'] ?? null,
        ]);

        SecurityEvent::create([
            'type' => $data['login_throttle_relaxed'] ? 'security.login_throttle_relaxed_enabled' : 'security.login_throttle_relaxed_disabled',
            'severity' => $data['login_throttle_relaxed'] ? 'medium' : 'info',
            'user_id' => $request->user()->id,
            'username' => $request->user()->username,
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 500),
            'payload' => [
                'until' => $data['login_throttle_relaxed_until'] ?? null,
                'reason' => $data['login_throttle_relaxed_reason'] ?? null,
            ],
        ]);

        return $this->policies($request);
    }

    public function releaseLock(Request $request, SecurityLock $lock)
    {
        $this->authorizeManage($request);

        $lock->update(['is_active' => false, 'locked_until' => null]);
        $this->auditLogger->record($request, 'security.lock_released', $lock);

        return $lock->refresh();
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_security')) {
            abort(403, '无权访问安全中心');
        }
    }

    private function relaxedUntilIsActive(?string $value): bool
    {
        if (! filled($value)) {
            return true;
        }

        try {
            return Carbon::parse($value)->isFuture();
        } catch (\Throwable) {
            return false;
        }
    }
}
