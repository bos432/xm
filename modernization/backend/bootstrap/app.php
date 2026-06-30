<?php

use App\Http\Middleware\EnsureActiveUser;
use App\Models\SecurityEvent;
use App\Support\RuntimeConfig;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Middleware\HandleCors;
use Illuminate\Http\Request;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Routing\Middleware\SubstituteBindings;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->api(prepend: [
            HandleCors::class,
        ]);

        $middleware->alias([
            'bindings' => SubstituteBindings::class,
            'active' => EnsureActiveUser::class,
        ]);

        RateLimiter::for('auth-login', function (Request $request) {
            $ip = (string) $request->ip();
            $whitelist = collect(explode(',', RuntimeConfig::value('security.login_throttle_whitelist_ips', '') ?? ''))
                ->map(fn (string $item) => trim($item))
                ->filter()
                ->all();

            if (RuntimeConfig::boolValue('security.login_throttle_relaxed', false) || in_array($ip, $whitelist, true)) {
                return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_relaxed_per_minute', 60)))
                    ->by($ip.'|'.(string) $request->input('username', ''));
            }

            return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_per_minute', 5)))
                ->by($ip.'|'.(string) $request->input('username', ''));
        });
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(function (ThrottleRequestsException $exception, Request $request) {
            $retryAfter = (int) ($exception->getHeaders()['Retry-After'] ?? 60);

            if ($request->is('api/auth/login')) {
                SecurityEvent::create([
                    'type' => 'auth.throttled',
                    'severity' => 'medium',
                    'username' => (string) $request->input('username', ''),
                    'ip_address' => $request->ip(),
                    'user_agent' => substr((string) $request->userAgent(), 0, 500),
                    'payload' => [
                        'username' => (string) $request->input('username', ''),
                        'retry_after_seconds' => $retryAfter,
                    ],
                ]);
            }

            if ($request->expectsJson() || $request->is('api/*')) {
                return response()->json([
                    'message' => '登录过于频繁，请稍后再试',
                    'retry_after_seconds' => $retryAfter,
                ], 429);
            }
        });
    })
    ->create();
