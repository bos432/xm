<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
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
            'score' => 82,
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
            'score' => 86,
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
            'score' => 95,
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
}
