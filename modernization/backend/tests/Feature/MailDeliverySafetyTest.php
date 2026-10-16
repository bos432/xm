<?php

namespace Tests\Feature;

use App\Jobs\SendMailLogJob;
use App\Models\MailLog;
use App\Models\User;
use App\Support\RuntimeConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MailDeliverySafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_log_mailer_does_not_log_sensitive_body_or_mark_message_as_sent(): void
    {
        config(['mail.default' => 'smtp']);
        RuntimeConfig::set('mail.mailer', 'log', 'mail', false);
        $log = MailLog::create([
            'to_address' => 'recipient@example.com',
            'subject' => 'Password reset',
            'body' => 'https://example.com/reset?token=secret-token',
            'status' => 'queued',
        ]);

        Mail::shouldReceive('raw')->never();
        (new SendMailLogJob($log->id))->handle();

        $this->assertSame('failed', $log->refresh()->status);
        $this->assertNull($log->sent_at);
        $this->assertStringContainsString('请配置 SMTP', $log->error);
    }

    public function test_smtp_mailer_sends_message_and_marks_it_sent(): void
    {
        config(['mail.default' => 'log']);
        RuntimeConfig::set('mail.mailer', 'smtp', 'mail', false);
        $log = MailLog::create([
            'to_address' => 'recipient@example.com',
            'subject' => 'Notification',
            'body' => 'A test notification',
            'status' => 'queued',
        ]);

        Mail::shouldReceive('raw')->once()->with('A test notification', \Mockery::type('Closure'))->andReturnNull();
        (new SendMailLogJob($log->id))->handle();

        $this->assertSame('sent', $log->refresh()->status);
        $this->assertNotNull($log->sent_at);
    }

    public function test_test_mail_endpoint_rejects_non_delivery_mailer_without_creating_a_log(): void
    {
        $admin = User::factory()->create(['role' => 'super_admin']);
        RuntimeConfig::set('mail.mailer', 'log', 'mail', false);
        Sanctum::actingAs($admin);

        $this->postJson('/api/settings/mail/test', ['to' => 'recipient@example.com'])
            ->assertUnprocessable()
            ->assertJsonPath('message', '请先配置并启用 SMTP，当前邮件驱动不会实际投递邮件');

        $this->assertDatabaseCount('mail_logs', 0);
    }
}
