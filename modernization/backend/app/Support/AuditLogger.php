<?php

namespace App\Support;

use App\Models\OperationLog;
use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\Model;

class AuditLogger
{
    public function record(Request $request, string $action, ?Model $target = null, array $payload = []): void
    {
        OperationLog::create([
            'user_id' => $request->user()?->id,
            'action' => $action,
            'target_type' => $target ? $target::class : null,
            'target_id' => $target?->getKey(),
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 500),
            'payload' => $payload,
        ]);
    }
}

