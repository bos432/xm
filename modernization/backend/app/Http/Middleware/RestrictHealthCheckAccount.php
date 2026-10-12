<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class RestrictHealthCheckAccount
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        if (! $user || ! ($user->metadata['health_check'] ?? false)) {
            return $next($request);
        }

        if ($request->routeIs('api.auth.logout')) {
            return $next($request);
        }

        abort(403, '健康检查账号仅允许退出登录');
    }
}
