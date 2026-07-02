<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\MigrationBatch;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\SecurityEvent;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DashboardSummaryTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_summary_is_scoped_to_own_unit(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        Project::factory()->create(['unit_id' => $ownUnit->id, 'owner_id' => $user->id, 'status' => Project::STATUS_DRAFT]);
        Project::factory()->create(['unit_id' => $ownUnit->id, 'owner_id' => $user->id, 'status' => Project::STATUS_REVIEWING]);
        Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '单位自己的延期申请',
                    'status' => 'pending',
                ]],
            ],
        ]);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        Project::factory()->create(['unit_id' => $otherUnit->id, 'owner_id' => $otherOwner->id, 'status' => Project::STATUS_REVIEWING]);
        Message::create(['recipient_id' => $user->id, 'title' => '未读消息']);
        OperationLog::create(['user_id' => $user->id, 'action' => 'project.created']);

        Sanctum::actingAs($user);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('projects.total', 3)
            ->assertJsonPath('projects.by_status.draft', 1)
            ->assertJsonPath('projects.by_status.reviewing', 1)
            ->assertJsonPath('projects.submitted_or_reviewing', 1)
            ->assertJsonPath('acceptance.pending_extensions', 0)
            ->assertJsonPath('messages.unread', 1)
            ->assertJsonPath('reviews.pending', 0)
            ->assertJsonPath('security', null)
            ->assertJsonPath('migration', null);
    }

    public function test_reviewer_summary_counts_current_role_tasks(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
        ]);

        Sanctum::actingAs($county);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('projects.total', 2)
            ->assertJsonPath('reviews.pending', 1);
    }

    public function test_admin_summary_includes_migration_context(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $target = User::factory()->create(['username' => 'failed-user']);
        MigrationBatch::create([
            'name' => '核心数据预演',
            'mode' => 'dry_run',
            'source_path' => 'scripts/mock.sql',
            'status' => 'blocked',
        ]);
        SecurityEvent::create([
            'user_id' => $target->id,
            'type' => 'auth.login_failed',
            'severity' => 'warning',
            'ip_address' => '10.0.0.8',
            'username' => 'failed-user',
            'payload' => ['username' => 'failed-user', 'reason' => 'invalid_password'],
            'created_at' => now()->subHours(2),
            'updated_at' => now()->subHours(2),
        ]);
        SecurityEvent::create([
            'type' => 'auth.captcha_failed',
            'severity' => 'warning',
            'ip_address' => '10.0.0.7',
            'username' => 'captcha-user',
            'payload' => ['username' => 'captcha-user', 'reason' => 'invalid_captcha'],
            'created_at' => now()->subHour(),
            'updated_at' => now()->subHour(),
        ]);
        SecurityEvent::create([
            'type' => 'unit.tokens_revoked',
            'severity' => 'info',
            'payload' => ['reason' => 'unit_deactivated', 'revoked_tokens' => 3],
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        SecurityEvent::create([
            'type' => 'project_file.invalid_path',
            'severity' => 'warning',
            'payload' => ['disk' => 'local', 'path' => '../outside.pdf'],
            'created_at' => now()->addMinute(),
            'updated_at' => now()->addMinute(),
        ]);
        SecurityEvent::create([
            'type' => 'project_file.invalid_disk',
            'severity' => 'warning',
            'payload' => ['disk' => 'public', 'path' => 'project-files/1/public.pdf'],
            'created_at' => now()->addMinutes(2),
            'updated_at' => now()->addMinutes(2),
        ]);
        SecurityEvent::create([
            'type' => 'auth.login_failed',
            'severity' => 'warning',
            'ip_address' => '10.0.0.9',
            'username' => 'old-user',
            'payload' => ['username' => 'old-user', 'reason' => 'unknown_account'],
            'created_at' => now()->subDays(2),
            'updated_at' => now()->subDays(2),
        ]);
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [
                    ['reason' => '待处理延期一', 'status' => 'pending'],
                    ['reason' => '待处理延期二', 'status' => 'pending'],
                    ['reason' => '已处理延期', 'status' => 'approved'],
                ],
            ],
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('acceptance.pending_extensions', 2)
            ->assertJsonPath('migration.latest_batch.name', '核心数据预演')
            ->assertJsonPath('migration.latest_batch.status', 'blocked')
            ->assertJsonPath('security.security_events_24h', 5)
            ->assertJsonPath('security.recent_security_events.0.type', 'project_file.invalid_disk')
            ->assertJsonPath('security.recent_security_events.0.payload.disk', 'public')
            ->assertJsonPath('security.recent_security_events.1.type', 'project_file.invalid_path');
    }
}
