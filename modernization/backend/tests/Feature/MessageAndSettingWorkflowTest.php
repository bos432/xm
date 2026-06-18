<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MessageAndSettingWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_only_lists_own_messages(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $otherUser = User::factory()->create(['role' => 'unit']);
        $ownMessage = Message::create([
            'recipient_id' => $user->id,
            'type' => 'project',
            'title' => '自己的消息',
            'body' => '只应自己可见',
        ]);
        Message::create([
            'recipient_id' => $otherUser->id,
            'type' => 'project',
            'title' => '别人的消息',
            'body' => '不应出现在列表中',
        ]);

        Sanctum::actingAs($user);

        $ids = collect($this->getJson('/api/messages')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($ownMessage->id));
        $this->assertCount(1, $ids);
    }

    public function test_user_can_filter_own_messages_by_status_and_type(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $otherUser = User::factory()->create(['role' => 'unit']);
        $unreadReview = Message::create([
            'recipient_id' => $user->id,
            'type' => 'review',
            'title' => '未读审核消息',
        ]);
        Message::create([
            'recipient_id' => $user->id,
            'type' => 'project',
            'title' => '未读项目消息',
        ]);
        Message::create([
            'recipient_id' => $user->id,
            'type' => 'review',
            'title' => '已读审核消息',
            'read_at' => now(),
        ]);
        Message::create([
            'recipient_id' => $otherUser->id,
            'type' => 'review',
            'title' => '别人未读审核消息',
        ]);

        Sanctum::actingAs($user);

        $ids = collect($this->getJson('/api/messages?status=unread&type=review')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($unreadReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_user_can_mark_all_own_unread_messages_read(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $otherUser = User::factory()->create(['role' => 'unit']);
        $first = Message::create([
            'recipient_id' => $user->id,
            'type' => 'review',
            'title' => '第一条未读',
        ]);
        $second = Message::create([
            'recipient_id' => $user->id,
            'type' => 'project',
            'title' => '第二条未读',
        ]);
        $alreadyRead = Message::create([
            'recipient_id' => $user->id,
            'type' => 'project',
            'title' => '已经读过',
            'read_at' => now()->subMinute(),
        ]);
        $otherMessage = Message::create([
            'recipient_id' => $otherUser->id,
            'type' => 'review',
            'title' => '其他用户未读',
        ]);

        Sanctum::actingAs($user);

        $this->postJson('/api/messages/read-all')
            ->assertOk()
            ->assertJsonPath('updated', 2);

        $this->assertNotNull($first->refresh()->read_at);
        $this->assertNotNull($second->refresh()->read_at);
        $this->assertNotNull($alreadyRead->refresh()->read_at);
        $this->assertNull($otherMessage->refresh()->read_at);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'message.read_all',
        ]);

        $this->postJson('/api/messages/read-all')
            ->assertOk()
            ->assertJsonPath('updated', 0);
        $this->assertDatabaseCount('operation_logs', 1);
    }

    public function test_user_can_mark_own_message_read_once(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $message = Message::create([
            'recipient_id' => $user->id,
            'type' => 'review',
            'title' => '审核通知',
            'body' => '项目审核状态更新',
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/messages/{$message->id}/read")
            ->assertOk()
            ->assertJsonPath('id', $message->id);
        $this->assertNotNull($message->refresh()->read_at);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'message.read',
            'target_type' => Message::class,
            'target_id' => $message->id,
        ]);

        $this->postJson("/api/messages/{$message->id}/read")->assertOk();
        $this->assertDatabaseCount('operation_logs', 1);
    }

    public function test_user_cannot_mark_another_users_message_read(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $otherUser = User::factory()->create(['role' => 'unit']);
        $message = Message::create([
            'recipient_id' => $otherUser->id,
            'type' => 'project',
            'title' => '其他用户消息',
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/messages/{$message->id}/read")->assertForbidden();
        $this->assertNull($message->refresh()->read_at);
    }

    public function test_admin_can_update_setting_with_audit_log_and_secret_masking(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $setting = SystemSetting::create([
            'key' => 'mail.password',
            'value' => 'old-secret',
            'group' => 'mail',
            'is_secret' => true,
            'description' => '邮件密码',
        ]);

        Sanctum::actingAs($admin);

        $this->putJson("/api/settings/{$setting->id}", [
            'value' => 'new-secret',
            'description' => '新的邮件密码',
        ])->assertOk()
            ->assertJsonPath('key', 'mail.password')
            ->assertJsonPath('value', '********')
            ->assertJsonPath('description', '新的邮件密码');

        $this->assertDatabaseHas('system_settings', [
            'id' => $setting->id,
            'value' => 'new-secret',
            'description' => '新的邮件密码',
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'setting.updated',
            'target_type' => SystemSetting::class,
            'target_id' => $setting->id,
        ]);
    }

    public function test_blank_secret_setting_update_keeps_existing_value(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $setting = SystemSetting::create([
            'key' => 'sms.api_key',
            'value' => 'existing-secret',
            'group' => 'sms',
            'is_secret' => true,
            'description' => '短信密钥',
        ]);

        Sanctum::actingAs($admin);

        $this->putJson("/api/settings/{$setting->id}", [
            'value' => '',
            'description' => '只更新说明',
        ])->assertOk()
            ->assertJsonPath('key', 'sms.api_key')
            ->assertJsonPath('value', '********')
            ->assertJsonPath('description', '只更新说明');

        $this->assertDatabaseHas('system_settings', [
            'id' => $setting->id,
            'value' => 'existing-secret',
            'description' => '只更新说明',
        ]);
    }

    public function test_non_admin_cannot_update_setting(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $setting = SystemSetting::create([
            'key' => 'site.name',
            'value' => '项目申报系统',
            'group' => 'general',
            'is_secret' => false,
        ]);

        Sanctum::actingAs($user);

        $this->putJson("/api/settings/{$setting->id}", [
            'value' => '越权修改',
        ])->assertForbidden();
        $this->assertDatabaseHas('system_settings', [
            'id' => $setting->id,
            'value' => '项目申报系统',
        ]);
    }
}
