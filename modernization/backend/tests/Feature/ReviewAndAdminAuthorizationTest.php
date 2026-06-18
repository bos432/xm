<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\SystemSetting;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReviewAndAdminAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_user_cannot_access_review_tasks_or_review_project(): void
    {
        $unit = Unit::factory()->create();
        $unitUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $unitUser->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($unitUser);

        $this->getJson('/api/reviews/tasks')->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'comment' => '单位用户不能审核自己的项目',
        ])->assertForbidden();
    }

    public function test_reviewer_can_only_process_current_stage_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $countyReviewer = User::factory()->create(['role' => 'county']);
        $departmentReviewer = User::factory()->create(['role' => 'department']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($departmentReviewer);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'comment' => '部门越级审核',
        ])->assertForbidden();

        Sanctum::actingAs($countyReviewer);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'score' => 88,
            'comment' => '区县审核通过',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REVIEWING)
            ->assertJsonPath('project.current_reviewer_role', 'department');

        $this->assertDatabaseHas('project_reviews', [
            'project_id' => $project->id,
            'reviewer_id' => $countyReviewer->id,
            'stage' => 'county',
            'decision' => 'approve',
        ]);
    }

    public function test_reviewer_tasks_are_scoped_to_reviewer_role(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $countyReviewer = User::factory()->create(['role' => 'county']);
        $countyProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        $departmentProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
        ]);

        Sanctum::actingAs($countyReviewer);

        $ids = collect($this->getJson('/api/reviews/tasks')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($countyProject->id));
        $this->assertFalse($ids->contains($departmentProject->id));
    }

    public function test_reviewer_tasks_can_be_filtered_by_keyword_within_current_role(): void
    {
        $matchedUnit = Unit::factory()->create(['name' => '东城创新单位']);
        $otherUnit = Unit::factory()->create(['name' => '西城服务单位']);
        $matchedOwner = User::factory()->create(['unit_id' => $matchedUnit->id, 'role' => 'unit', 'username' => 'east-owner']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit', 'username' => 'west-owner']);
        $countyReviewer = User::factory()->create(['role' => 'county']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $matchedUnit->id,
            'owner_id' => $matchedOwner->id,
            'title' => '智能制造申报项目',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $otherOwner->id,
            'title' => '普通服务申报项目',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        Project::factory()->create([
            'unit_id' => $matchedUnit->id,
            'owner_id' => $matchedOwner->id,
            'title' => '部门阶段智能制造项目',
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
        ]);

        Sanctum::actingAs($countyReviewer);

        $ids = collect($this->getJson('/api/reviews/tasks?keyword=智能制造')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($matchedProject->id));
        $this->assertCount(1, $ids);
    }

    public function test_reviewer_tasks_can_be_filtered_by_project_id_within_current_role(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $countyReviewer = User::factory()->create(['role' => 'county']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        $otherCountyProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        $departmentProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
        ]);

        Sanctum::actingAs($countyReviewer);

        $ids = collect($this->getJson('/api/reviews/tasks?project_id='.$matchedProject->id)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($matchedProject->id));
        $this->assertFalse($ids->contains($otherCountyProject->id));
        $this->assertCount(1, $ids);

        $ids = collect($this->getJson('/api/reviews/tasks?project_id='.$departmentProject->id)->assertOk()->json('data'))->pluck('id');
        $this->assertCount(0, $ids);
    }

    public function test_reviewer_tasks_can_be_filtered_by_category_and_project_type(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $matched = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '科技重点审核项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '产业示范审核项目',
            'category' => '产业项目',
            'project_type' => '创新示范',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($county);

        $ids = collect($this->getJson('/api/reviews/tasks?category=' . urlencode('科技项目') . '&project_type=' . urlencode('重点扶持'))->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($matched->id));
        $this->assertCount(1, $ids);
    }

    public function test_reviewer_results_can_be_filtered_by_category_and_project_type(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '科技重点结果项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '产业示范结果项目',
            'category' => '产业项目',
            'project_type' => '创新示范',
        ]);
        $matchedReview = ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '科技项目通过',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $otherProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '产业项目通过',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $ids = collect($this->getJson('/api/reviews/results?category=' . urlencode('科技项目') . '&project_type=' . urlencode('重点扶持'))
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($matchedReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_reviewer_results_can_be_filtered_by_score_range(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '评分区间结果项目',
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 79.5,
            'comment' => '低于区间',
            'reviewed_at' => now(),
        ]);
        $matchedReview = ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 85,
            'comment' => '位于评分区间',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 91,
            'comment' => '高于区间',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $ids = collect($this->getJson('/api/reviews/results?score_min=80&score_max=90')
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($matchedReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_reviewer_results_can_be_filtered_by_project_id_within_current_stage(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '指定审核结果项目',
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '其它审核结果项目',
        ]);
        $matchedReview = ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县指定结果',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $otherProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县其它结果',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'comment' => '部门同项目结果',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $ids = collect($this->getJson('/api/reviews/results?project_id='.$matchedProject->id)
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($matchedReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_only_admin_can_view_migration_readiness_and_settings(): void
    {
        $unitUser = User::factory()->create(['role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        SystemSetting::create([
            'key' => 'mail.host',
            'value' => 'smtp.example.test',
            'group' => 'mail',
            'is_secret' => false,
        ]);

        Sanctum::actingAs($unitUser);
        $this->getJson('/api/migration/readiness')->assertForbidden();
        $this->getJson('/api/settings')->assertForbidden();

        Sanctum::actingAs($admin);
        $this->getJson('/api/migration/readiness')->assertOk();
        $this->getJson('/api/settings')->assertOk()
            ->assertJsonFragment(['key' => 'mail.host']);
    }
}
