<?php

namespace App\Http\Controllers;

use App\Models\MailLog;
use App\Models\MailTemplate;
use App\Support\AuditLogger;
use App\Support\MailCenter;
use App\Support\Role;
use Illuminate\Http\Request;

class MailCenterController extends Controller
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MailCenter $mailCenter,
    )
    {
    }

    public function templates(Request $request)
    {
        $this->authorizeManage($request);

        return MailTemplate::query()
            ->orderByDesc('is_builtin')
            ->orderBy('key')
            ->get();
    }

    public function storeTemplate(Request $request)
    {
        $this->authorizeManage($request);

        $template = MailTemplate::create($this->validatedTemplate($request));
        $this->auditLogger->record($request, 'mail_template.created', $template);

        return response()->json($template, 201);
    }

    public function updateTemplate(Request $request, MailTemplate $template)
    {
        $this->authorizeManage($request);

        $template->update($this->validatedTemplate($request, $template));
        $this->auditLogger->record($request, 'mail_template.updated', $template);

        return $template->refresh();
    }

    public function logs(Request $request)
    {
        $this->authorizeManage($request);

        $query = MailLog::query()->with('template')->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('to_address', 'like', '%'.$keyword.'%')
                    ->orWhere('subject', 'like', '%'.$keyword.'%')
                    ->orWhere('template_key', 'like', '%'.$keyword.'%');
            });
        }

        return $query->paginate(20);
    }

    public function retry(Request $request, MailLog $log)
    {
        $this->authorizeManage($request);

        $this->mailCenter->retry($log, $request->user());
        $this->auditLogger->record($request, 'mail_log.retry', $log);

        return $log->refresh();
    }

    private function validatedTemplate(Request $request, ?MailTemplate $template = null): array
    {
        $id = $template?->id ?? 'NULL';

        return $request->validate([
            'key' => ['required', 'string', 'max:120', 'unique:mail_templates,key,'.$id],
            'name' => ['required', 'string', 'max:160'],
            'subject' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string'],
            'is_active' => ['required', 'boolean'],
            'metadata' => ['nullable', 'array'],
        ]) + ['is_builtin' => $template?->is_builtin ?? false];
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_mail')) {
            abort(403, '无权管理邮件中心');
        }
    }
}
