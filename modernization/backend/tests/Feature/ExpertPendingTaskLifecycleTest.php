<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExpertPendingTaskLifecycleTest extends TestCase
{
    use RefreshDatabase;

    public function test_expert_return_then_resubmission_requires_fresh_scores_without_deleting_history(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $county = User::factory()->create(['role' => 'county']);
        $department = User::factory()->create(['role' => 'department']);
        $first = User::factory()->create(['role' => 'expert']);
        $second = User::factory()->create(['role' => 'expert']);
        $batch = ApplicationBatch::create([
            'name' => 'QA Resubmission', 'code' => 'QA-RESUBMIT', 'status' => 'open',
            'starts_at' => now()->subDay(), 'ends_at' => now()->addDay(),
        ]);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id, 'application_batch_id' => $batch->id,
            'status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => 'expert',
            'metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
                'stage' => 'expert', 'auto_assign' => true, 'assigned_user_ids' => [$first->id, $second->id],
            ]]]],
        ]);
        Sanctum::actingAs($first);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 80])->assertCreated();
        Sanctum::actingAs($second);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'return', 'comment' => 'Clarify evidence'])
            ->assertCreated()->assertJsonPath('project.status', Project::STATUS_RETURNED);
        Sanctum::actingAs($owner);
        $this->getJson("/api/projects/{$project->id}")
            ->assertOk()->assertJsonPath('expert_review_summary.reviewed_count', 0)
            ->assertJsonPath('expert_review_summary.pending_count', 2);
        $this->postJson("/api/projects/{$project->id}/submit")->assertOk();
        foreach ([$county, $department] as $reviewer) {
            Sanctum::actingAs($reviewer);
            $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'approve'])->assertCreated();
        }
        Sanctum::actingAs($first);
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 90])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'expert');
        Sanctum::actingAs($owner);
        $this->getJson("/api/projects/{$project->id}")
            ->assertOk()->assertJsonPath('expert_review_summary.reviewed_count', 1)
            ->assertJsonPath('expert_review_summary.pending_count', 1);
        Sanctum::actingAs($second);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 95])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'admin');
        $this->assertSame(4, $project->reviews()->where('stage', 'expert')->count());
        Sanctum::actingAs($owner);
        $this->getJson("/api/projects/{$project->id}")
            ->assertOk()->assertJsonPath('expert_review_summary.reviewed_count', 2)
            ->assertJsonPath('expert_review_summary.pending_count', 0);
    }

    public function test_completed_expert_leaves_pending_tasks_while_other_assigned_expert_can_finish(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $first = User::factory()->create(['role' => 'expert']);
        $second = User::factory()->create(['role' => 'expert']);
        $outsider = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => 'QA-EXPERT-PENDING-LIFECYCLE',
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'expert',
            'metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
                'stage' => 'expert',
                'auto_assign' => true,
                'assigned_user_ids' => [$first->id, $second->id],
            ]]]],
        ]);

        Sanctum::actingAs($outsider);
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('reviews.pending', 0)->assertJsonPath('role_focus.review_pending', 0);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend'])
            ->assertForbidden();

        Sanctum::actingAs($first);
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 90])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'expert');
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('reviews.pending', 0)->assertJsonPath('role_focus.review_pending', 0);
        $csv = $this->get('/api/reviews/tasks/export.csv')->assertOk()->streamedContent();
        $this->assertStringNotContainsString($project->title, $csv);
        $this->getJson('/api/reviews/results')->assertOk()->assertJsonPath('data.0.project_id', $project->id);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 95])
            ->assertUnprocessable();

        Sanctum::actingAs($second);
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->getJson('/api/dashboard/summary')->assertOk()
            ->assertJsonPath('reviews.pending', 1)->assertJsonPath('role_focus.review_pending', 1);
        $this->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'recommend', 'score' => 80])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'admin');
        $this->getJson('/api/reviews/tasks')->assertOk()->assertJsonCount(0, 'data');
        $this->assertDatabaseCount('project_reviews', 2);
    }
}
