<?php

namespace App\Jobs;

use App\Models\MailLog;
use App\Support\RuntimeConfig;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

class SendMailLogJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(private readonly int $mailLogId)
    {
    }

    public function handle(): void
    {
        $log = MailLog::query()->find($this->mailLogId);
        if (! $log || $log->status === 'sent') {
            return;
        }

        RuntimeConfig::applyMailSettings();

        try {
            Mail::raw($log->body, function ($message) use ($log): void {
                $message->to($log->to_address, $log->to_name)->subject($log->subject);
            });

            $log->update([
                'status' => 'sent',
                'error' => null,
                'sent_at' => now(),
            ]);
        } catch (\Throwable $exception) {
            $log->update([
                'status' => 'failed',
                'error' => mb_substr($exception->getMessage(), 0, 2000),
            ]);

            throw $exception;
        }
    }
}
