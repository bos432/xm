<?php

namespace App\Providers;

use App\Models\SecurityEvent;
use App\Support\RuntimeConfig;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Carbon;

class AuthRateLimitServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        RateLimiter::for('auth-login', function (Request $request) {
            $ip = (string) $request->ip();
            $respond = function (Request $request, array $headers) use ($ip) {
                $retryAfter = (int) ($headers['Retry-After'] ?? 60);
                SecurityEvent::create([
                    'type' => 'auth.throttled',
                    'severity' => 'medium',
                    'username' => (string) $request->input('username', ''),
                    'ip_address' => $ip,
                    'user_agent' => substr((string) $request->userAgent(), 0, 500),
                    'payload' => [
                        'retry_after_seconds' => $retryAfter,
                    ],
                ]);

                return response()->json([
                    'message' => '登录过于频繁，请稍后再试',
                    'retry_after_seconds' => $retryAfter,
                ], 429, $headers);
            };

            $whitelist = collect(explode(',', RuntimeConfig::value('security.login_throttle_whitelist_ips', '') ?? ''))
                ->map(fn (string $item) => trim($item))
                ->filter()
                ->all();

            $relaxedUntil = RuntimeConfig::value('security.login_throttle_relaxed_until');
            $relaxedActive = RuntimeConfig::boolValue('security.login_throttle_relaxed', false)
                && $this->relaxedUntilIsActive($relaxedUntil);

            if ($relaxedActive || in_array($ip, $whitelist, true)) {
                return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_relaxed_per_minute', 60)))
                    ->by($ip.'|'.(string) $request->input('username', ''))
                    ->response($respond);
            }

            return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_per_minute', 5)))
                ->by($ip.'|'.(string) $request->input('username', ''))
                ->response($respond);
        });
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
