<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\Unit;
use App\Models\User;
use App\Support\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReviewWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_project_can_move_through_full_review_chain(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $expert = User::factory()->create(['role' => 'expert']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
            'submitted_at' => now(),
        ]);

        Sanctum::actingAs($county);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'comment' => '区县通过',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REVIEWING)
            ->assertJsonPath('project.current_reviewer_role', 'department');
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $department->id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '收到待审项目',
        ]);

        Sanctum::actingAs($department);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'comment' => '部门通过',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REVIEWING)
            ->assertJsonPath('project.current_reviewer_role', 'expert');
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $expert->id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '收到待审项目',
        ]);

        Sanctum::actingAs($expert);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'recommend',
            'score' => 91,
            'comment' => '专家推荐',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REVIEWING)
            ->assertJsonPath('project.current_reviewer_role', 'admin');
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $admin->id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '收到待审项目',
        ]);

        Sanctum::actingAs($admin);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'accept',
            'comment' => '终审通过',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_APPROVED)
            ->assertJsonPath('project.current_reviewer_role', null);

        $this->assertDatabaseCount('project_reviews', 4);
        $this->assertDatabaseHas('operation_logs', ['action' => 'project.reviewed']);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $owner->id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '项目审核状态更新',
        ]);
    }

    public function test_return_decision_sends_project_back_to_applicant(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($county);

        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'return',
            'comment' => '请补充材料',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_RETURNED)
            ->assertJsonPath('project.current_reviewer_role', null);
    }

    public function test_reject_decision_closes_project_review_path(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_SUBMITTED,
            'current_reviewer_role' => 'county',
        ]);

        Sanctum::actingAs($county);

        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'reject',
            'comment' => '不符合条件',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REJECTED)
            ->assertJsonPath('project.current_reviewer_role', null);
    }

    public function test_all_assigned_experts_complete_the_stage_using_nested_dispatch_snapshot(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $firstExpert = User::factory()->create(['role' => 'expert']);
        $secondExpert = User::factory()->create(['role' => 'expert']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'expert',
            'metadata' => [
                'review_dispatch' => [
                    'assignments' => [
                        'expert' => [
                            'assigned_user_ids' => [$firstExpert->id, $secondExpert->id],
                        ],
                    ],
                ],
            ],
        ]);

        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $firstExpert->id,
            'stage' => 'expert',
            'decision' => 'recommend',
            'score' => 91,
            'comment' => '专家一已完成',
            'reviewed_at' => now()->subMinute(),
        ]);

        Sanctum::actingAs($secondExpert);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'recommend',
            'score' => 93,
            'comment' => '专家二已完成',
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_REVIEWING)
            ->assertJsonPath('project.current_reviewer_role', 'admin');

        $this->assertDatabaseHas('messages', [
            'recipient_id' => $admin->id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '收到待审项目',
        ]);
    }

    public function test_admin_final_review_persists_support_information_on_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $expert = User::factory()->create(['role' => 'expert', 'name' => '专家甲']);
        $admin = User::factory()->create(['role' => 'admin', 'name' => '终审管理员']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'admin',
            'metadata' => ['management_unit' => '盟科技局'],
        ]);
        ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $expert->id,
            'stage' => 'expert',
            'decision' => 'recommend',
            'score' => 92,
            'comment' => '专家推荐',
            'reviewed_at' => now()->subDay(),
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'accept',
            'comment' => '终审支持',
            'metadata' => [
                'final_support' => [
                    'is_recommended' => true,
                    'is_supported' => true,
                    'support_type' => 'subsidy',
                    'support_amount_wan' => 38.5,
                ],
            ],
        ])->assertCreated()
            ->assertJsonPath('project.status', Project::STATUS_APPROVED)
            ->assertJsonPath('project.metadata.final_support.support_amount_wan', 38.5)
            ->assertJsonPath('project.metadata.final_support.recommended_experts', '专家甲');

        $project->refresh();
        $this->assertSame('盟科技局', $project->metadata['management_unit']);
        $this->assertSame('subsidy', $project->metadata['final_support']['support_type']);
        $this->assertSame('终审管理员', $project->metadata['final_support']['reviewed_by_name']);
    }

    public function test_only_one_concurrent_expert_review_can_advance_the_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $expert = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => Role::EXPERT,
            'metadata' => [
                'review_dispatch' => [
                    'assignments' => [
                        Role::EXPERT => [
                            'stage' => Role::EXPERT,
                            'auto_assign' => true,
                            'assigned_user_ids' => [$expert->id],
                        ],
                    ],
                ],
            ],
        ]);

        Sanctum::actingAs($expert);

        $payload = ['decision' => 'recommend', 'metadata' => ['score_criteria' => []]];
        $this->postJson("/api/projects/{$project->id}/reviews", $payload)->assertCreated();
        $this->postJson("/api/projects/{$project->id}/reviews", $payload)->assertForbidden();

        $this->assertDatabaseCount('project_reviews', 1);
        $this->assertSame(Role::ADMIN, $project->refresh()->current_reviewer_role);
    }

    public function test_expert_assignment_snapshot_is_preserved_until_every_assigned_expert_reviews(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $department = User::factory()->create(['role' => Role::DEPARTMENT]);
        $experts = User::factory()->count(4)->create(['role' => Role::EXPERT]);
        $admin = User::factory()->create(['role' => Role::ADMIN]);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => Role::DEPARTMENT,
        ]);

        Sanctum::actingAs($department);
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'approve',
            'comment' => '部门审核通过',
        ])->assertCreated()
            ->assertJsonPath('project.current_reviewer_role', Role::EXPERT);

        $project->refresh();
        $assignedIds = array_map('intval', data_get($project->metadata, 'review_dispatch.assignments.expert.assigned_user_ids', []));
        $this->assertCount(3, $assignedIds);
        $this->assertTrue(collect($assignedIds)->every(fn (int $id): bool => $experts->pluck('id')->contains($id)));
        $assigned = User::query()->whereIn('id', $assignedIds)->orderBy('id')->get();

        foreach ($assigned->take(2) as $expert) {
            Sanctum::actingAs($expert);
            $this->postJson("/api/projects/{$project->id}/reviews", [
                'decision' => 'recommend',
                'metadata' => ['score_criteria' => []],
            ])->assertCreated()
                ->assertJsonPath('project.current_reviewer_role', Role::EXPERT);

            $storedIds = data_get($project->fresh()->metadata, 'review_dispatch.assignments.expert.assigned_user_ids');
            $this->assertEqualsCanonicalizing($assignedIds, array_map('intval', $storedIds));
        }

        $this->assertSame(2, ProjectReview::query()->where('project_id', $project->id)->where('stage', Role::EXPERT)->count());

        Sanctum::actingAs($assigned->last());
        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'recommend',
            'metadata' => ['score_criteria' => []],
        ])->assertCreated()
            ->assertJsonPath('project.current_reviewer_role', Role::ADMIN);

        $this->assertSame(3, ProjectReview::query()->where('project_id', $project->id)->where('stage', Role::EXPERT)->count());
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $admin->id,
            'project_id' => $project->id,
            'title' => '收到待审项目',
        ]);
    }
}
