<?php

namespace App\Support;

use App\Jobs\SendMailLogJob;
use App\Models\MailLog;
use App\Models\MailTemplate;
use App\Models\User;

final class MailCenter
{
    public function queueTemplate(string $key, string $to, array $variables = [], ?User $triggeredBy = null, ?string $toName = null): MailLog
    {
        $template = MailTemplate::query()
            ->where('key', $key)
            ->where('is_active', true)
            ->first();

        if (! $template) {
            $template = new MailTemplate([
                'key' => $key,
                'name' => $key,
                'subject' => $variables['subject'] ?? $key,
                'body' => $variables['body'] ?? '',
            ]);
        }

        $log = MailLog::create([
            'mail_template_id' => $template->exists ? $template->id : null,
            'template_key' => $key,
            'to_address' => $to,
            'to_name' => $toName,
            'subject' => $this->render($template->subject, $variables),
            'body' => $this->render($template->body, $variables),
            'status' => 'queued',
            'queued_at' => now(),
            'triggered_by' => $triggeredBy?->id,
            'metadata' => ['variables' => $variables],
        ]);

        SendMailLogJob::dispatch($log->id);

        return $log;
    }

    public function retry(MailLog $log, ?User $triggeredBy = null): MailLog
    {
        $log->update([
            'status' => 'queued',
            'error' => null,
            'retry_count' => $log->retry_count + 1,
            'queued_at' => now(),
            'triggered_by' => $triggeredBy?->id ?? $log->triggered_by,
        ]);

        SendMailLogJob::dispatch($log->id);

        return $log->refresh();
    }

    private function render(string $text, array $variables): string
    {
        foreach ($variables as $key => $value) {
            if (is_array($value) || is_object($value)) {
                continue;
            }

            $text = str_replace('{{ '.$key.' }}', (string) $value, $text);
            $text = str_replace('{{'.$key.'}}', (string) $value, $text);
        }

        return $text;
    }
}
