<?php

use App\Http\Middleware\AddSecurityHeaders;
use App\Http\Middleware\Authenticate as ApiAwareAuthenticate;
use App\Http\Middleware\EnsureActiveUser;
use App\Http\Middleware\RestrictHealthCheckAccount;
use App\Models\SecurityEvent;
use App\Providers\AuthRateLimitServiceProvider;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Routing\Middleware\SubstituteBindings;

require_once __DIR__.'/../app/Console/Commands/UploadOssBackups.php';

return Application::configure(basePath: dirname(__DIR__))
    ->withProviders([
        AuthRateLimitServiceProvider::class,
        \Laravel\Sanctum\SanctumServiceProvider::class,
    ])
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        then: function (): void {
            \Illuminate\Support\Facades\Route::get('/up', function () {
                $exception = null;

                try {
                    \Illuminate\Support\Facades\Event::dispatch(new \Illuminate\Foundation\Events\DiagnosingHealth);
                } catch (\Throwable $e) {
                    if (app()->hasDebugModeEnabled()) {
                        throw $e;
                    }

                    report($e);
                    $exception = $e->getMessage();
                }

                $healthView = dirname((new \ReflectionClass(\Illuminate\Foundation\Configuration\ApplicationBuilder::class))->getFileName()).'/../resources/health-up.blade.php';

                return response(\Illuminate\Support\Facades\View::file(
                    $healthView,
                    ['exception' => $exception],
                ), status: $exception ? 500 : 200);
            })->middleware(AddSecurityHeaders::class);
        },
    )
    ->withCommands([
        App\Console\Commands\UploadOssBackups::class,
    ])
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : '/login');
        $middleware->append(AddSecurityHeaders::class);
        $middleware->alias([
            'auth' => ApiAwareAuthenticate::class,
            'bindings' => SubstituteBindings::class,
            'active' => EnsureActiveUser::class,
            'health-check-only' => RestrictHealthCheckAccount::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->shouldRenderJsonWhen(fn (Request $request): bool => $request->is('api/*') || $request->expectsJson());

        $exceptions->render(function (AuthenticationException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Unauthenticated.'], 401);
            }
        });

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
