<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExpertPendingTaskLifecycleTest extends TestCase
{
    use RefreshDatabase;

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
