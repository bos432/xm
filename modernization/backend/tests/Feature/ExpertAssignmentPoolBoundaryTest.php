<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\Project;
use App\Models\ReviewDispatchRule;
use App\Models\Unit;
use App\Models\User;
use App\Support\ReviewDispatchMatcher;
use App\Support\RuntimeConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExpertAssignmentPoolBoundaryTest extends TestCase
{
    use RefreshDatabase;

    private function officialProject(): Project
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);

        return Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'metadata' => [],
        ]);
    }

    public function test_formal_project_does_not_assign_explicitly_marked_test_expert(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '3', 'review', false);
        $official = User::factory()->count(3)->create(['role' => 'expert', 'is_active' => true]);
        $testExpert = User::factory()->create([
            'role' => 'expert', 'is_active' => true, 'metadata' => ['e2e' => true],
        ]);
        RuntimeConfig::set('review.expert_assignment.random_enabled', 'false', 'review', false);
        $project = $this->officialProject();

        $assignment = app(ReviewDispatchMatcher::class)->apply($project, 'expert');

        $this->assertNotContains($testExpert->id, $assignment['assigned_user_ids']);
        $this->assertEqualsCanonicalizing($official->modelKeys(), $assignment['assigned_user_ids']);
    }

    public function test_requested_three_experts_cannot_silently_become_two(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '3', 'review', false);
        RuntimeConfig::set('review.expert_assignment.random_enabled', 'true', 'review', false);
        User::factory()->count(2)->create(['role' => 'expert', 'is_active' => true]);
        $project = $this->officialProject();
        $before = $project->metadata;

        try {
            app(ReviewDispatchMatcher::class)->apply($project, 'expert');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('expert_assignment', $exception->errors());
            $this->assertSame($before, $project->metadata);

            return;
        }

        $this->fail('Configured three-expert assignment must reject a two-expert pool without changing metadata.');
    }

    public function test_existing_assignment_snapshot_is_not_recomputed(): void
    {
        $project = $this->officialProject();
        $snapshot = ['stage' => 'expert', 'auto_assign' => true, 'assigned_user_ids' => [123456], 'expert_count' => 1];
        $project->metadata = ['review_dispatch' => ['assignments' => ['expert' => $snapshot]]];
        $project->save();

        $this->assertSame($snapshot, app(ReviewDispatchMatcher::class)->apply($project, 'expert'));
        $this->assertSame($snapshot, app(ReviewDispatchMatcher::class)->assignment($project->fresh(), 'expert'));
    }

    public function test_insufficient_preview_does_not_grant_review_access_or_mutate_project(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '3', 'review', false);
        $expert = User::factory()->create(['role' => 'expert', 'is_active' => true]);
        $project = $this->officialProject();
        $before = $project->refresh()->getRawOriginal();
        $matcher = app(ReviewDispatchMatcher::class);

        $preview = $matcher->previewAssignment($project, 'expert');
        $this->assertSame([], $preview['assigned_user_ids']);
        $this->assertNotEmpty($preview['assignment_error']);
        $this->assertFalse($matcher->userCanReview($project, $expert, 'expert'));
        $this->assertSame($before, $project->fresh()->getRawOriginal());
    }

    public function test_rule_targets_cannot_bypass_formal_test_pool_boundary(): void
    {
        RuntimeConfig::set('review.expert_assignment.random_enabled', 'false', 'review', false);
        $official = User::factory()->create(['role' => 'expert', 'is_active' => true]);
        $test = User::factory()->create(['role' => 'expert', 'is_active' => true, 'metadata' => ['e2e' => true]]);
        ReviewDispatchRule::create([
            'name' => 'Explicit pool', 'target_stage' => 'expert', 'is_active' => true,
            'auto_assign' => true, 'expert_count' => 1, 'recommended_user_ids' => [$official->id, $test->id],
        ]);
        $project = $this->officialProject();
        $matcher = app(ReviewDispatchMatcher::class);
        $preview = $matcher->previewAssignment($project, 'expert');
        $assignment = $matcher->apply($project, 'expert');
        $this->assertSame([$official->id], $assignment['assigned_user_ids']);
        $this->assertSame($preview['assigned_user_ids'], $assignment['assigned_user_ids']);
    }

    public function test_explicit_test_project_uses_only_explicit_test_experts(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '1', 'review', false);
        User::factory()->create(['role' => 'expert', 'is_active' => true]);
        $test = User::factory()->create(['role' => 'expert', 'is_active' => true, 'metadata' => ['e2e' => 'true']]);
        $project = $this->officialProject();
        $project->owner->update(['metadata' => ['e2e' => true]]);
        $this->assertSame([$test->id], app(ReviewDispatchMatcher::class)->apply($project, 'expert')['assigned_user_ids']);
    }

    public function test_insufficient_capacity_rolls_back_department_review_and_notifications(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '3', 'review', false);
        User::factory()->count(2)->create(['role' => 'expert', 'is_active' => true]);
        $department = User::factory()->create(['role' => 'department']);
        $project = $this->officialProject();
        $project->update(['status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => 'department']);
        $before = $project->refresh()->getRawOriginal();
        Sanctum::actingAs($department);

        $this->postJson('/api/projects/'.$project->id.'/reviews', ['decision' => 'approve'])
            ->assertUnprocessable()->assertJsonValidationErrors('expert_assignment');
        $this->assertSame($before, $project->fresh()->getRawOriginal());
        $this->assertDatabaseCount('project_reviews', 0);
        $this->assertDatabaseCount('operation_logs', 0);
        $this->assertDatabaseCount('messages', 0);
    }

    public function test_e2e_batch_selects_test_pool_without_project_metadata_marker(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '1', 'review', false);
        $test = User::factory()->create(['role' => 'expert', 'metadata' => ['e2e' => true]]);
        User::factory()->create(['role' => 'expert']);
        $batch = ApplicationBatch::create(['name' => 'E2E-Isolated', 'code' => 'E2E-Isolated', 'status' => 'open']);
        $project = $this->officialProject();
        $project->update(['application_batch_id' => $batch->id]);
        $this->assertSame([$test->id], app(ReviewDispatchMatcher::class)->apply($project, 'expert')['assigned_user_ids']);
    }

    public function test_applicant_metadata_cannot_switch_formal_project_to_test_pool(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '1', 'review', false);
        $ordinary = User::factory()->create(['role' => 'expert']);
        User::factory()->create(['role' => 'expert', 'metadata' => ['e2e' => true]]);
        $project = $this->officialProject();
        $project->metadata = ['e2e' => true];
        $this->assertSame([$ordinary->id], app(ReviewDispatchMatcher::class)->apply($project, 'expert')['assigned_user_ids']);
    }

    public function test_reserved_legacy_expert_is_excluded_but_ordinary_display_name_is_not(): void
    {
        RuntimeConfig::set('review.expert_assignment.random_enabled', 'false', 'review', false);
        $ordinary = User::factory()->create(['role' => 'expert', 'name' => 'QA Test Research Expert', 'metadata' => ['e2e' => 'false']]);
        User::factory()->create(['role' => 'expert', 'username' => 'e2e_20261106ops_expert']);
        $this->assertSame([$ordinary->id], app(ReviewDispatchMatcher::class)->apply($this->officialProject(), 'expert')['assigned_user_ids']);
    }

    public function test_rule_count_overrides_default_and_rejects_insufficient_filtered_targets(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '1', 'review', false);
        $official = User::factory()->create(['role' => 'expert']);
        $test = User::factory()->create(['role' => 'expert', 'metadata' => ['e2e' => true]]);
        ReviewDispatchRule::create([
            'name' => 'Need two', 'target_stage' => 'expert', 'is_active' => true,
            'auto_assign' => true, 'expert_count' => 2, 'recommended_user_ids' => [$official->id, $test->id],
        ]);
        $project = $this->officialProject();
        $matcher = app(ReviewDispatchMatcher::class);
        $this->assertSame([], $matcher->previewAssignment($project, 'expert')['assigned_user_ids']);
        $this->expectException(ValidationException::class);
        $matcher->apply($project, 'expert');
    }

    public function test_documented_legacy_dated_experts_cannot_enter_formal_pool(): void
    {
        RuntimeConfig::set('review.expert_assignment.random_enabled', 'false', 'review', false);
        $ordinary = User::factory()->create(['role' => 'expert']);
        User::factory()->create(['role' => 'expert', 'username' => 'e2e_20260630_103223_expert']);
        User::factory()->create(['role' => 'expert', 'username' => 'e2e_20260630_103223_expert_2']);

        $this->assertSame([$ordinary->id], app(ReviewDispatchMatcher::class)->apply($this->officialProject(), 'expert')['assigned_user_ids']);
    }

    public function test_documented_legacy_dated_owner_selects_test_pool(): void
    {
        RuntimeConfig::set('review.expert_assignment.count', '1', 'review', false);
        User::factory()->create(['role' => 'expert']);
        $test = User::factory()->create(['role' => 'expert', 'metadata' => ['e2e' => true]]);
        $project = $this->officialProject();
        $project->owner->update(['username' => 'e2e_20260630_103223_unit']);

        $this->assertSame([$test->id], app(ReviewDispatchMatcher::class)->apply($project, 'expert')['assigned_user_ids']);
    }
}
