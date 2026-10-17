<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
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

    public function test_open_batch_summary_excludes_system_history_batch(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);

        ApplicationBatch::create([
            'name' => '已过期正式批次',
            'code' => 'BUSINESS-EXPIRED',
            'starts_at' => now()->subDays(10),
            'ends_at' => now()->subDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('batches.open', 0)
            ->assertJsonPath('batches.current', null);
    }

    public function test_open_batch_summary_excludes_e2e_batches(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        ApplicationBatch::create([
            'name' => 'E2E-OPEN 自动化批次',
            'code' => 'E2E-OPEN-BATCH',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('batches.open', 0)
            ->assertJsonPath('batches.current', null);
    }

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

    public function test_admin_summary_hides_system_operations_details(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        SecurityEvent::create([
            'type' => 'auth.login_failed',
            'severity' => 'warning',
            'ip_address' => '203.0.113.10',
            'username' => 'private-account',
            'payload' => ['username' => 'private-account'],
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('security', null)
            ->assertJsonPath('migration', null)
            ->assertJsonPath('operation_logs', null)
            ->assertJsonMissingPath('role_focus.security_events_24h')
            ->assertJsonMissingPath('security.recent_security_events.0.ip_address')
            ->assertJsonMissingPath('operation_logs.recent.0.user.username');
    }

    public function test_super_admin_summary_includes_system_operations_details(): void
    {
        $superAdmin = User::factory()->create(['role' => 'super_admin']);
        SecurityEvent::create([
            'type' => 'auth.login_failed',
            'severity' => 'warning',
            'ip_address' => '203.0.113.11',
            'username' => 'audited-account',
            'payload' => ['username' => 'audited-account'],
        ]);
        MigrationBatch::create([
            'name' => '迁移门禁上下文',
            'mode' => 'dry_run',
            'source_path' => 'scripts/mock.sql',
            'status' => 'blocked',
        ]);
        OperationLog::create([
            'user_id' => $superAdmin->id,
            'action' => 'auth.login_success',
            'target_type' => User::class,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('security.recent_security_events.0.ip_address', '203.0.113.11')
            ->assertJsonPath('migration.latest_batch.name', '迁移门禁上下文')
            ->assertJsonPath('operation_logs.recent.0.action', 'auth.login_success');
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
            ->assertJsonPath('migration', null)
            ->assertJsonPath('security', null)
            ->assertJsonPath('operation_logs', null);
    }
}
