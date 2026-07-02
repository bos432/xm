<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\DictionaryItem;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReviewExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_reviewer_exports_only_current_role_tasks(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $countyTask = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '区县待审核项目',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
            'submitted_at' => now(),
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '部门待审核项目',
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
            'submitted_at' => now(),
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '已退回项目',
            'status' => Project::STATUS_RETURNED,
            'current_reviewer_role' => null,
        ]);

        Sanctum::actingAs($county);

        $response = $this->get('/api/reviews/tasks/export.csv');

        $response->assertOk();
        $csv = $response->streamedContent();
        $this->assertStringContainsString('项目ID', $csv);
        $this->assertStringContainsString($countyTask->title, $csv);
        $this->assertStringNotContainsString('部门待审核项目', $csv);
        $this->assertStringNotContainsString('已退回项目', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $county->id,
            'action' => 'review_tasks.exported',
        ]);
    }

    public function test_reviewer_task_export_can_be_filtered_by_keyword(): void
    {
        $unit = Unit::factory()->create(['name' => '东城创新单位']);
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $matchedTask = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '智能制造审核任务',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
            'submitted_at' => now(),
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '普通服务审核任务',
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
            'submitted_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $csv = $this->get('/api/reviews/tasks/export.csv?keyword=' . urlencode('智能制造'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString($matchedTask->title, $csv);
        $this->assertStringNotContainsString('普通服务审核任务', $csv);
    }

    public function test_unit_user_cannot_export_review_tasks(): void
    {
        $user = User::factory()->create(['role' => 'unit']);

        Sanctum::actingAs($user);

        $this->get('/api/reviews/tasks/export.csv')->assertForbidden();
    }

    public function test_reviewer_exports_only_own_stage_review_results(): void
    {
        $unit = Unit::factory()->create(['name' => '示例申报单位']);
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '审核结果项目',
            'status' => Project::STATUS_REVIEWING,
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 88,
            'comment' => '区县同意推荐',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'score' => 60,
            'comment' => '部门退回补充',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $response = $this->get('/api/reviews/results/export.csv');

        $response->assertOk();
        $csv = $response->streamedContent();
        $this->assertStringContainsString('审核ID', $csv);
        $this->assertStringContainsString('审核结果项目', $csv);
        $this->assertStringContainsString('区县同意推荐', $csv);
        $this->assertStringNotContainsString('部门退回补充', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $county->id,
            'action' => 'review_results.exported',
        ]);
    }

    public function test_reviewer_lists_only_own_stage_review_results_with_keyword_filter(): void
    {
        $unit = Unit::factory()->create(['name' => '示例申报单位']);
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '智能制造结果项目',
        ]);
        $countyReview = ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 88,
            'comment' => '区县智能制造意见',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'score' => 60,
            'comment' => '部门智能制造意见',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $ids = collect($this->getJson('/api/reviews/results?keyword=' . urlencode('智能制造'))
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($countyReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_admin_can_filter_review_results_by_stage_and_decision(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '管理员筛选项目',
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县通过',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'comment' => '部门退回',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/reviews/results/export.csv?stage=department&decision=return')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('部门退回', $csv);
        $this->assertStringNotContainsString('区县通过', $csv);
    }

    public function test_review_result_export_can_be_filtered_by_category_and_project_type(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '科技重点导出项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '产业示范导出项目',
            'category' => '产业项目',
            'project_type' => '创新示范',
        ]);
        ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '科技导出通过',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $otherProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '产业导出通过',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $csv = $this->get('/api/reviews/results/export.csv?category=' . urlencode('科技项目') . '&project_type=' . urlencode('重点扶持'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('科技导出通过', $csv);
        $this->assertStringContainsString('科技重点导出项目', $csv);
        $this->assertStringNotContainsString('产业导出通过', $csv);
        $this->assertStringNotContainsString('产业示范导出项目', $csv);
    }

    public function test_review_result_export_can_be_filtered_by_score_range(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '评分区间导出项目',
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 79.5,
            'comment' => '导出低于区间',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 85,
            'comment' => '导出位于评分区间',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 91,
            'comment' => '导出高于区间',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $csv = $this->get('/api/reviews/results/export.csv?score_min=80&score_max=90')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('导出位于评分区间', $csv);
        $this->assertStringNotContainsString('导出低于区间', $csv);
        $this->assertStringNotContainsString('导出高于区间', $csv);
    }

    public function test_review_result_export_includes_expert_score_criteria_columns(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $expert = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '专家评分导出项目',
        ]);
        DictionaryItem::create([
            'group' => 'expert_review_criterion',
            'code' => 'policy_importance',
            'label' => '项目实施的重要性、必要性',
            'sort_order' => 10,
            'is_active' => true,
            'metadata' => ['section' => '政策符合性评价', 'max_score' => 5],
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $expert->id,
            'stage' => 'expert',
            'decision' => 'recommend',
            'score' => 4,
            'comment' => '专家建议推荐',
            'reviewed_at' => now(),
            'metadata' => [
                'score_criteria' => [
                    [
                        'code' => 'policy_importance',
                        'label' => '项目实施的重要性、必要性',
                        'section' => '政策符合性评价',
                        'max_score' => 5,
                        'score' => 4,
                    ],
                ],
            ],
        ]);

        Sanctum::actingAs($expert);

        $csv = $this->get('/api/reviews/results/export.csv')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('项目实施的重要性、必要性（5分）', $csv);
        $this->assertStringContainsString('专家评分导出项目', $csv);
        $this->assertStringContainsString(',4,专家建议推荐', $csv);
    }

    public function test_admin_can_list_review_results_by_stage_and_decision(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '管理员结果项目',
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县通过',
            'reviewed_at' => now(),
        ]);
        $departmentReview = ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'comment' => '部门退回',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($admin);

        $ids = collect($this->getJson('/api/reviews/results?stage=department&decision=return')
            ->assertOk()
            ->json('data'))->pluck('id');

        $this->assertTrue($ids->contains($departmentReview->id));
        $this->assertCount(1, $ids);
    }

    public function test_review_result_export_can_be_filtered_by_project_id_within_current_stage(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $matchedProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '指定导出结果项目',
        ]);
        $otherProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '其它导出结果项目',
        ]);
        ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县指定导出结果',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $otherProject->id,
            'reviewer_id' => $county->id,
            'stage' => 'county',
            'decision' => 'approve',
            'comment' => '区县其它导出结果',
            'reviewed_at' => now(),
        ]);
        ProjectReview::create([
            'project_id' => $matchedProject->id,
            'reviewer_id' => $department->id,
            'stage' => 'department',
            'decision' => 'return',
            'comment' => '部门同项目导出结果',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($county);

        $csv = $this->get('/api/reviews/results/export.csv?project_id='.$matchedProject->id)
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('区县指定导出结果', $csv);
        $this->assertStringNotContainsString('区县其它导出结果', $csv);
        $this->assertStringNotContainsString('部门同项目导出结果', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $county->id,
            'action' => 'review_results.exported',
        ]);
    }

    public function test_unit_user_cannot_export_review_results(): void
    {
        $user = User::factory()->create(['role' => 'unit']);

        Sanctum::actingAs($user);

        $this->get('/api/reviews/results/export.csv')->assertForbidden();
    }
}
