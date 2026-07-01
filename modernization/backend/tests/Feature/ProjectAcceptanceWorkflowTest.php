<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\AcceptanceApplication;
use App\Models\AcceptanceReview;
use App\Models\ApplicationBatch;
use App\Models\ProjectFile;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectAcceptanceWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_filter_e2e_projects_and_acceptances(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $e2eBatch = ApplicationBatch::create([
            'name' => 'E2E 筛选批次',
            'code' => 'E2E-FILTER-BATCH',
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);
        $businessBatch = ApplicationBatch::create([
            'name' => '正式筛选批次',
            'code' => 'BUSINESS-FILTER-BATCH',
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);
        $e2eProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'application_batch_id' => $e2eBatch->id,
            'title' => 'E2E-筛选项目',
            'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $businessProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'application_batch_id' => $businessBatch->id,
            'title' => '正式筛选项目',
            'status' => Project::STATUS_ACCEPTANCE,
        ]);
        AcceptanceApplication::create([
            'project_id' => $e2eProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => 'admin',
        ]);
        AcceptanceApplication::create([
            'project_id' => $businessProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => 'admin',
        ]);

        Sanctum::actingAs($admin);

        $e2eProjects = collect($this->getJson('/api/projects?e2e=1')->assertOk()->json('data'));
        $businessProjects = collect($this->getJson('/api/projects?e2e=0')->assertOk()->json('data'));
        $e2eAcceptances = collect($this->getJson('/api/acceptance?scope=visible&e2e=1')->assertOk()->json('data'));
        $businessAcceptances = collect($this->getJson('/api/acceptance?scope=visible&e2e=0')->assertOk()->json('data'));

        $this->assertTrue($e2eProjects->pluck('id')->contains($e2eProject->id));
        $this->assertFalse($e2eProjects->pluck('id')->contains($businessProject->id));
        $this->assertTrue($businessProjects->pluck('id')->contains($businessProject->id));
        $this->assertFalse($businessProjects->pluck('id')->contains($e2eProject->id));
        $this->assertTrue($e2eAcceptances->pluck('project_id')->contains($e2eProject->id));
        $this->assertFalse($e2eAcceptances->pluck('project_id')->contains($businessProject->id));
        $this->assertTrue($businessAcceptances->pluck('project_id')->contains($businessProject->id));
        $this->assertFalse($businessAcceptances->pluck('project_id')->contains($e2eProject->id));
    }

    public function test_reviewer_can_filter_pending_and_reviewed_acceptance_records(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $pendingProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $reviewedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_CLOSED,
        ]);
        $pendingAcceptance = AcceptanceApplication::create([
            'project_id' => $pendingProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
            'submitted_at' => now(),
        ]);
        $reviewedAcceptance = AcceptanceApplication::create([
            'project_id' => $reviewedProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_CLOSED,
            'current_reviewer_role' => null,
            'submitted_at' => now(),
        ]);
        AcceptanceReview::create([
            'acceptance_application_id' => $reviewedAcceptance->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $pending = collect($this->getJson('/api/acceptance?scope=pending')->assertOk()->json('data'));
        $reviewed = collect($this->getJson('/api/acceptance?scope=reviewed')->assertOk()->json('data'));
        $visible = collect($this->getJson('/api/acceptance?scope=visible')->assertOk()->json('data'));

        $this->assertTrue($pending->pluck('id')->contains($pendingAcceptance->id));
        $this->assertFalse($pending->pluck('id')->contains($reviewedAcceptance->id));
        $this->assertTrue($reviewed->pluck('id')->contains($reviewedAcceptance->id));
        $this->assertFalse($reviewed->pluck('id')->contains($pendingAcceptance->id));
        $this->assertTrue($visible->pluck('id')->contains($pendingAcceptance->id));
        $this->assertTrue($visible->pluck('id')->contains($reviewedAcceptance->id));
        $this->getJson("/api/acceptance/{$reviewedAcceptance->id}")->assertOk();
    }

    public function test_unit_cannot_view_other_unit_acceptance_record(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $owner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $acceptance = AcceptanceApplication::create([
            'project_id' => $project->id,
            'unit_id' => $otherUnit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($user);

        $this->getJson('/api/acceptance')->assertOk()
            ->assertJsonCount(0, 'data');
        $this->getJson("/api/acceptance/{$acceptance->id}")->assertForbidden();
    }

    public function test_acceptance_submit_requires_configured_material_categories(): void
    {
        $batch = ApplicationBatch::create([
            'name' => '验收材料批次',
            'code' => 'ACCEPT-MATERIALS',
            'status' => ApplicationBatch::STATUS_OPEN,
            'metadata' => [
                'acceptance_required_materials' => ['acceptance_application', 'project_summary'],
            ],
        ]);
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'application_batch_id' => $batch->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $acceptance = AcceptanceApplication::create([
            'project_id' => $project->id,
            'unit_id' => $unit->id,
            'submitted_by' => $user->id,
            'status' => AcceptanceApplication::STATUS_DRAFT,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/acceptance/{$acceptance->id}/submit", [
            'summary' => '提交验收',
        ])->assertUnprocessable()
            ->assertJsonPath('missing_materials.0', '验收申请书')
            ->assertJsonPath('missing_materials.1', '项目总结');

        foreach (['acceptance_application', 'project_summary'] as $category) {
            ProjectFile::create([
                'project_id' => $project->id,
                'uploaded_by' => $user->id,
                'disk' => 'local',
                'path' => 'project-files/test.pdf',
                'original_name' => $category.'.pdf',
                'mime_type' => 'application/pdf',
                'extension' => 'pdf',
                'size_bytes' => 10,
                'sha256' => str_repeat('a', 64),
                'purpose' => 'acceptance',
                'metadata' => [
                    'acceptance_id' => $acceptance->id,
                    'material_category' => $category,
                ],
            ]);
        }

        $this->postJson("/api/acceptance/{$acceptance->id}/submit", [
            'summary' => '材料齐全',
        ])->assertOk()
            ->assertJsonPath('status', AcceptanceApplication::STATUS_SUBMITTED)
            ->assertJsonPath('current_reviewer_role', 'county');
    }

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
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $ownDraft = Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $otherOwner->id,
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
