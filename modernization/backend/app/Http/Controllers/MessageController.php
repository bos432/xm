<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Support\AuditLogger;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $status = $request->query('status');

        return Message::query()
            ->where('recipient_id', $request->user()->id)
            ->when($request->filled('type'), function ($query) use ($request) {
                $query->where('type', $request->query('type'));
            })
            ->when($status === 'unread', function ($query) {
                $query->whereNull('read_at');
            })
            ->when($status === 'read', function ($query) {
                $query->whereNotNull('read_at');
            })
            ->latest()
            ->paginate(20);
    }

    public function markAllRead(Request $request)
    {
        $query = Message::query()
            ->where('recipient_id', $request->user()->id)
            ->whereNull('read_at');

        $updated = $query->count();

        if ($updated > 0) {
            $query->update(['read_at' => now()]);
            $this->auditLogger->record($request, 'message.read_all', null, [
                'count' => $updated,
            ]);
        }

        return ['updated' => $updated];
    }

    public function markRead(Request $request, Message $message)
    {
        if ($message->recipient_id !== $request->user()->id) {
            abort(403, '无权读取该消息');
        }

        if (! $message->read_at) {
            $message->update(['read_at' => now()]);
            $this->auditLogger->record($request, 'message.read', $message, [
                'type' => $message->type,
                'project_id' => $message->project_id,
            ]);
        }

        return $message->refresh();
    }
}
