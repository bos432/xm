<?php

namespace App\Support;

use App\Models\SecurityEvent;
use App\Models\SecurityIpRule;
use App\Models\SecurityLock;
use App\Models\User;
use Illuminate\Http\Request;

final class SecurityService
{
    public function assertLoginAllowed(Request $request, ?string $username = null): void
    {
        $ip = $request->ip();

        if ($this->ipRulesEnabled('whitelist') && ! $this->matchesIpRule($ip, 'whitelist')) {
            $this->recordEvent($request, 'security.ip_not_whitelisted', 'high', $username);
            abort(403, '当前 IP 不在允许访问范围内');
        }

        if ($this->ipRulesEnabled('blacklist') && $this->matchesIpRule($ip, 'blacklist')) {
            $this->recordEvent($request, 'security.ip_blacklisted', 'high', $username);
            abort(403, '当前 IP 已被限制访问');
        }

        foreach ([['ip', $ip], ['username', $username]] as [$type, $value]) {
            if (! $value) {
                continue;
            }

            $lock = SecurityLock::query()
                ->where('identity_type', $type)
                ->where('identity_value', $value)
                ->where('is_active', true)
                ->latest()
                ->first();

            if ($lock && $lock->isLocked()) {
                $retryAfter = $lock->locked_until
                    ? max(1, now()->diffInSeconds($lock->locked_until, false))
                    : max(60, RuntimeConfig::intValue('security.lock_minutes', 30) * 60);
                $this->recordEvent($request, 'security.login_blocked', 'high', $username, null, [
                    'identity_type' => $type,
                    'identity_value' => $value,
                    'locked_until' => $lock->locked_until?->toDateTimeString(),
                    'retry_after_seconds' => $retryAfter,
                ]);
                abort(response()->json([
                    'message' => '登录失败次数过多，请稍后再试或联系管理员解锁',
                    'retry_after_seconds' => $retryAfter,
                ], 423));
            }

            if ($lock && ! $lock->isLocked()) {
                $lock->update(['is_active' => false]);
            }
        }
    }

    public function recordFailure(Request $request, string $username, string $reason, ?User $user = null): void
    {
        $this->recordEvent($request, 'auth.login_failed', 'medium', $username, $user, ['reason' => $reason]);

        $threshold = max(1, RuntimeConfig::intValue('security.login_failure_threshold', 5));
        $lockMinutes = max(1, RuntimeConfig::intValue('security.lock_minutes', 30));

        foreach ([['username', $username], ['ip', $request->ip()]] as [$type, $value]) {
            $lock = SecurityLock::query()->firstOrCreate(
                ['identity_type' => $type, 'identity_value' => $value, 'is_active' => true],
                ['failed_count' => 0]
            );
            $failedCount = $lock->failed_count + 1;
            $lock->update([
                'failed_count' => $failedCount,
                'reason' => $reason,
                'is_active' => $failedCount >= $threshold,
                'locked_until' => $failedCount >= $threshold ? now()->addMinutes($lockMinutes) : null,
            ]);
        }
    }

    public function recordSuccess(Request $request, User $user): void
    {
        SecurityLock::query()
            ->where(function ($query) use ($request, $user): void {
                $query->where(function ($query) use ($user): void {
                    $query->where('identity_type', 'username')->where('identity_value', $user->username);
                })->orWhere(function ($query) use ($request): void {
                    $query->where('identity_type', 'ip')->where('identity_value', $request->ip());
                });
            })
            ->whereNull('locked_until')
            ->update(['is_active' => false]);

        $this->recordEvent($request, 'auth.login', 'info', $user->username, $user);
    }

    public function recordEvent(Request $request, string $type, string $severity = 'info', ?string $username = null, ?User $user = null, array $payload = []): SecurityEvent
    {
        return SecurityEvent::create([
            'user_id' => $user?->id,
            'type' => $type,
            'severity' => $severity,
            'username' => $username,
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 500),
            'payload' => $payload,
        ]);
    }

    private function ipRulesEnabled(string $type): bool
    {
        return RuntimeConfig::boolValue('security.ip_'.$type.'_enabled', $type === 'blacklist');
    }

    private function matchesIpRule(string $ip, string $type): bool
    {
        return SecurityIpRule::query()
            ->where('type', $type)
            ->where('is_active', true)
            ->get()
            ->contains(fn (SecurityIpRule $rule) => $this->ipMatchesCidr($ip, $rule->cidr));
    }

    private function ipMatchesCidr(string $ip, string $cidr): bool
    {
        if ($ip === $cidr) {
            return true;
        }

        if (! str_contains($cidr, '/')) {
            return false;
        }

        [$subnet, $bits] = explode('/', $cidr, 2);
        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);
        $bits = (int) $bits;

        if ($ipLong === false || $subnetLong === false || $bits < 0 || $bits > 32) {
            return false;
        }

        $mask = -1 << (32 - $bits);

        return ($ipLong & $mask) === ($subnetLong & $mask);
    }
}
