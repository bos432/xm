<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectAcceptanceWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_start_acceptance_and_close_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_APPROVED,
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/projects/{$project->id}/enter-acceptance")
            ->assertOk()
            ->assertJsonPath('status', Project::STATUS_ACCEPTANCE);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'project.acceptance_started',
            'target_type' => Project::class,
            'target_id' => $project->id,
        ]);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $owner->id,
            'project_id' => $project->id,
            'title' => '项目进入验收',
        ]);

        $this->postJson("/api/projects/{$project->id}/close", [
            'comment' => '验收资料齐全',
        ])->assertOk()
            ->assertJsonPath('status', Project::STATUS_CLOSED)
            ->assertJsonPath('metadata.acceptance_closed.comment', '验收资料齐全');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'project.closed',
            'target_type' => Project::class,
            'target_id' => $project->id,
        ]);
    }

    public function test_unit_user_can_request_extension_for_approved_project(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $firstAdmin = User::factory()->create(['role' => 'admin']);
        $secondAdmin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/projects/{$project->id}/extension", [
            'reason' => '设备采购延期，需要顺延验收。',
            'expected_date' => '2026-09-30',
        ])->assertOk()
            ->assertJsonPath('metadata.extension_requests.0.reason', '设备采购延期，需要顺延验收。')
            ->assertJsonPath('metadata.extension_requests.0.expected_date', '2026-09-30')
            ->assertJsonPath('metadata.extension_requests.0.status', 'pending');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project.extension_requested',
            'target_type' => Project::class,
            'target_id' => $project->id,
        ]);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $firstAdmin->id,
            'project_id' => $project->id,
            'title' => '收到延期申请',
        ]);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $secondAdmin->id,
            'project_id' => $project->id,
            'title' => '收到延期申请',
        ]);
    }

    public function test_admin_can_review_pending_extension_request(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '验收材料补充',
                    'expected_date' => '2026-10-31',
                    'status' => 'pending',
                    'requested_at' => now()->toDateTimeString(),
                    'requested_by' => $owner->id,
                ]],
            ],
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/projects/{$project->id}/extension/0/review", [
            'decision' => 'approved',
            'comment' => '同意顺延',
        ])->assertOk()
            ->assertJsonPath('metadata.extension_requests.0.status', 'approved')
            ->assertJsonPath('metadata.extension_requests.0.review_comment', '同意顺延')
            ->assertJsonPath('metadata.extension_requests.0.reviewed_by', $admin->id);

        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'project.extension_reviewed',
            'target_type' => Project::class,
            'target_id' => $project->id,
        ]);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $owner->id,
            'project_id' => $project->id,
            'title' => '延期申请已通过',
        ]);

        $this->postJson("/api/projects/{$project->id}/extension/0/review", [
            'decision' => 'rejected',
        ])->assertUnprocessable();
    }

    public function test_admin_cannot_close_acceptance_with_pending_extension_request(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '验收延期',
                    'status' => 'pending',
                ]],
            ],
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/projects/{$project->id}/close", [
            'comment' => '仍有延期未处理',
        ])->assertUnprocessable()
            ->assertJsonPath('message', '存在待处理延期申请，不能关闭验收');

        $this->postJson("/api/projects/{$project->id}/extension/0/review", [
            'decision' => 'approved',
            'comment' => '同意延期',
        ])->assertOk();

        $this->postJson("/api/projects/{$project->id}/close", [
            'comment' => '延期已处理，关闭验收',
        ])->assertOk()
            ->assertJsonPath('status', Project::STATUS_CLOSED);
    }

    public function test_admin_can_filter_projects_with_pending_extension_requests(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $pendingProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '待处理延期项目',
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '验收材料补充',
                    'expected_date' => '2026-10-31',
                    'status' => 'pending',
                    'requested_at' => now()->toDateTimeString(),
                    'requested_by' => $owner->id,
                ]],
            ],
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '已处理延期项目',
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '已处理延期',
                    'status' => 'approved',
                ]],
            ],
        ]);

        Sanctum::actingAs($admin);

        $items = collect($this->getJson('/api/projects?pending_extension=1')
            ->assertOk()
            ->json('data'));

        $this->assertTrue($items->pluck('id')->contains($pendingProject->id));
        $this->assertCount(1, $items);
        $this->assertSame(1, $items->firstWhere('id', $pendingProject->id)['pending_extension_requests_count']);
    }

    public function test_non_admin_cannot_review_extension_request(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '验收延期',
                    'status' => 'pending',
                ]],
            ],
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/projects/{$project->id}/extension/0/review", [
            'decision' => 'approved',
        ])->assertForbidden();
    }

    public function test_non_admin_cannot_start_or_close_acceptance(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_APPROVED,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/projects/{$project->id}/enter-acceptance")->assertForbidden();

        $project->update(['status' => Project::STATUS_ACCEPTANCE]);
        $this->postJson("/api/projects/{$project->id}/close", [
            'comment' => '越权关闭',
        ])->assertForbidden();
    }

    public function test_extension_request_is_limited_to_own_unit_and_allowed_statuses(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $ownDraft = Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/projects/{$ownDraft->id}/extension", [
            'reason' => '草稿不能申请延期',
        ])->assertUnprocessable();
        $this->postJson("/api/projects/{$otherProject->id}/extension", [
            'reason' => '跨单位申请延期',
        ])->assertForbidden();
    }
}
