<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ReviewDispatchRule;
use App\Models\Unit;
use App\Models\User;
use App\Support\ReviewDispatchMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DispatchRuleAdministrationTest extends TestCase
{
    use RefreshDatabase;

    private function payload(array $overrides = []): array
    {
        return array_replace(['name' => 'QA dispatch', 'target_stage' => 'department',
            'recommended_user_ids' => [], 'auto_assign' => false, 'is_active' => true,
            'priority' => 100, 'remark' => 'QA retained only in memory'], $overrides);
    }

    public function test_unauthorized_roles_cannot_read_write_or_select_dispatch_users(): void
    {
        $rule = ReviewDispatchRule::create($this->payload());
        $this->getJson('/api/review-dispatch-rules')->assertUnauthorized();
        foreach (['unit', 'county', 'department', 'expert'] as $role) {
            Sanctum::actingAs(User::factory()->create(['role' => $role]));
            $this->getJson('/api/review-dispatch-rules')->assertForbidden();
            $this->getJson('/api/review-dispatch-rules/users')->assertForbidden();
            $this->postJson('/api/review-dispatch-rules', $this->payload())->assertForbidden();
            $this->putJson('/api/review-dispatch-rules/'.$rule->id, $this->payload(['name' => 'mutated']))->assertForbidden();
            $this->deleteJson('/api/review-dispatch-rules/'.$rule->id)->assertForbidden();
        }
        $this->assertSame('QA dispatch', $rule->fresh()->name);
        $this->assertDatabaseCount('review_dispatch_rules', 1);
    }

    public function test_admin_crud_filters_candidate_roles_and_snapshot_survives_rule_changes(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $department = User::factory()->create(['role' => 'department', 'is_active' => true]);
        $expert = User::factory()->create(['role' => 'expert', 'is_active' => true]);
        User::factory()->create(['role' => 'expert', 'is_active' => false]);
        User::factory()->create(['role' => 'unit']);
        Sanctum::actingAs($admin);
        $candidates = $this->getJson('/api/review-dispatch-rules/users')->assertOk()->json();
        $this->assertEqualsCanonicalizing([$department->id, $expert->id], array_column($candidates, 'id'));
        $this->getJson('/api/review-dispatch-rules/users?roles=expert,admin')->assertOk()->assertJsonCount(1)->assertJsonPath('0.id', $expert->id);
        $this->getJson('/api/review-dispatch-rules/users?roles=unit')->assertOk()->assertExactJson([]);
        $secondDepartment = User::factory()->create(['role' => 'department', 'is_active' => true]);
        $id = $this->postJson('/api/review-dispatch-rules', $this->payload([
            'recommended_user_ids' => [$secondDepartment->id, $department->id], 'management_unit' => 'QA management', 'auto_assign' => true,
        ]))->assertCreated()->assertJsonPath('created_by', $admin->id)->assertJsonPath('recommended_users.0.id', $secondDepartment->id)->json('id');
        $this->postJson('/api/review-dispatch-rules', $this->payload(['name' => 'Disabled', 'is_active' => false]))->assertCreated();
        $this->getJson('/api/review-dispatch-rules?target_stage=department&is_active=1&keyword=QA')->assertOk()->assertJsonPath('total', 1);
        $this->getJson('/api/review-dispatch-rules?is_active=0')->assertOk()->assertJsonPath('total', 1);
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id, 'metadata' => ['management_unit' => 'QA management']]);
        $matcher = app(ReviewDispatchMatcher::class);
        $snapshot = $matcher->apply($project, 'department');
        $project->save();
        $this->assertSame([$secondDepartment->id, $department->id], $snapshot['assigned_user_ids']);
        $this->putJson('/api/review-dispatch-rules/'.$id, $this->payload([
            'target_stage' => 'expert', 'recommended_user_ids' => [$expert->id], 'expert_count' => 1,
        ]))->assertOk()->assertJsonPath('expert_count', 1)->assertJsonPath('updated_by', $admin->id);
        $this->deleteJson('/api/review-dispatch-rules/'.$id)->assertNoContent();
        $this->assertSame($snapshot, $matcher->assignment($project->fresh(), 'department'));
        $this->assertDatabaseMissing('review_dispatch_rules', ['id' => $id]);
    }

    public function test_wrong_role_inactive_duplicate_or_missing_candidates_are_rejected_without_mutation(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        $valid = User::factory()->create(['role' => 'department', 'is_active' => true]);
        $wrong = User::factory()->create(['role' => 'unit']);
        $inactive = User::factory()->create(['role' => 'department', 'is_active' => false]);
        foreach ([[$valid->id, $wrong->id], [$inactive->id], [$valid->id, $valid->id], [999999]] as $ids) {
            $this->postJson('/api/review-dispatch-rules', $this->payload(['recommended_user_ids' => $ids]))
                ->assertUnprocessable();
        }
        $this->assertDatabaseCount('review_dispatch_rules', 0);
        $rule = ReviewDispatchRule::create($this->payload(['recommended_user_ids' => [$valid->id]]));
        $this->putJson('/api/review-dispatch-rules/'.$rule->id, $this->payload(['target_stage' => 'expert', 'recommended_user_ids' => [$valid->id]]))
            ->assertUnprocessable();
        $this->assertSame('department', $rule->fresh()->target_stage);
        $this->assertSame([$valid->id], $rule->fresh()->recommended_user_ids);
    }

    public function test_invalid_rule_fields_do_not_persist_partial_records(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        $this->postJson('/api/review-dispatch-rules', $this->payload([
            'name' => str_repeat('x', 161), 'target_stage' => 'admin', 'expert_count' => 21, 'priority' => -1,
        ]))->assertUnprocessable()->assertJsonValidationErrors(['name', 'target_stage', 'expert_count', 'priority']);
        $this->assertDatabaseCount('review_dispatch_rules', 0);
    }
}
