<?php

use App\Http\Middleware\EnsureActiveUser;
use App\Models\SecurityEvent;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Middleware\HandleCors;
use Illuminate\Http\Request;
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
