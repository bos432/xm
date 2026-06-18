<?php

namespace Tests\Feature;

use App\Models\OperationLog;
use App\Models\Project;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OperationLogManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_filter_operation_logs_by_action_target_type_and_target_id(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $projectLog = OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'target_type' => Project::class,
            'target_id' => 1001,
            'payload' => ['status' => 'submitted'],
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'message.read_all',
            'target_type' => null,
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'target_type' => Project::class,
            'target_id' => 1002,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/operation-logs?action=project.submitted&target_type=' . urlencode(Project::class) . '&target_id=1001')
            ->assertOk();

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($projectLog->id));
        $this->assertCount(1, $ids);
        $response->assertJsonPath('data.0.user.username', $admin->username);
        $response->assertJsonPath('data.0.payload.status', 'submitted');
    }

    public function test_admin_can_filter_operation_logs_by_date_range(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $insideLog = OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'created_at' => '2026-06-07 10:00:00',
            'updated_at' => '2026-06-07 10:00:00',
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.created',
            'created_at' => '2026-06-05 10:00:00',
            'updated_at' => '2026-06-05 10:00:00',
        ]);

        Sanctum::actingAs($admin);

        $ids = collect($this->getJson('/api/operation-logs?date_from=2026-06-07&date_to=2026-06-07')
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($insideLog->id));
        $this->assertCount(1, $ids);
    }

    public function test_admin_can_filter_operation_logs_by_keyword_and_ip_address(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $operator = User::factory()->create(['username' => 'audit-operator', 'name' => '审计员']);
        $matchedLog = OperationLog::create([
            'user_id' => $operator->id,
            'action' => 'auth.login',
            'ip_address' => '10.8.0.12',
            'user_agent' => 'Modern Browser',
            'payload' => ['username' => 'audit-operator'],
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.created',
            'ip_address' => '10.8.0.13',
            'payload' => ['title' => '其他项目'],
        ]);

        Sanctum::actingAs($admin);

        $ids = collect($this->getJson('/api/operation-logs?keyword=audit-operator&ip_address=10.8.0.12')
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($matchedLog->id));
        $this->assertCount(1, $ids);
    }

    public function test_non_admin_cannot_view_operation_logs(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        OperationLog::create(['user_id' => $user->id, 'action' => 'project.created']);

        Sanctum::actingAs($user);

        $this->getJson('/api/operation-logs')->assertForbidden();
    }

    public function test_admin_can_export_operation_logs_by_action_target_type_and_target_id(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'target_type' => Project::class,
            'target_id' => 1001,
            'payload' => ['status' => 'submitted'],
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'message.read_all',
            'target_type' => null,
            'payload' => ['count' => 3],
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'target_type' => Project::class,
            'target_id' => 1002,
            'payload' => ['status' => 'other'],
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/operation-logs/export.csv?action=project.submitted&target_type=' . urlencode(Project::class) . '&target_id=1001')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('日志ID', $csv);
        $this->assertStringContainsString('project.submitted', $csv);
        $this->assertStringContainsString('submitted', $csv);
        $this->assertStringNotContainsString('message.read_all', $csv);
        $this->assertStringNotContainsString('other', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'operation_log.exported',
        ]);
    }

    public function test_admin_can_export_operation_logs_by_date_range(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.submitted',
            'created_at' => '2026-06-07 10:00:00',
            'updated_at' => '2026-06-07 10:00:00',
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'project.created',
            'created_at' => '2026-06-05 10:00:00',
            'updated_at' => '2026-06-05 10:00:00',
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/operation-logs/export.csv?date_from=2026-06-07&date_to=2026-06-07')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('project.submitted', $csv);
        $this->assertStringNotContainsString('project.created', $csv);
    }

    public function test_admin_can_export_operation_logs_by_keyword_and_ip_address(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $operator = User::factory()->create(['username' => 'export-operator']);
        OperationLog::create([
            'user_id' => $operator->id,
            'action' => 'auth.login',
            'ip_address' => '172.16.1.9',
            'payload' => ['username' => 'export-operator'],
        ]);
        OperationLog::create([
            'user_id' => $admin->id,
            'action' => 'auth.login',
            'ip_address' => '172.16.1.10',
            'payload' => ['username' => 'admin'],
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/operation-logs/export.csv?keyword=export-operator&ip_address=172.16.1.9')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('export-operator', $csv);
        $this->assertStringContainsString('172.16.1.9', $csv);
        $this->assertStringNotContainsString('172.16.1.10', $csv);
    }

    public function test_non_admin_cannot_export_operation_logs(): void
    {
        $user = User::factory()->create(['role' => 'unit']);

        Sanctum::actingAs($user);

        $this->get('/api/operation-logs/export.csv')->assertForbidden();
    }
}
