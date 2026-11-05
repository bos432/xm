<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\RbacRole;
use App\Models\ReviewDispatchRule;
use App\Models\Unit;
use App\Models\User;
use App\Support\ReviewDispatchMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectExportScopeBoundaryTest extends TestCase
{
    use RefreshDatabase;

    public function test_unassigned_expert_options_are_empty(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject();
        Sanctum::actingAs($outsider);
        $this->getJson('/api/projects/options')->assertOk()->assertExactJson([]);
    }

    public function test_unassigned_expert_export_contains_no_project_and_audits_zero(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject();
        Sanctum::actingAs($outsider);
        $csv = $this->get('/api/projects/export.csv?keyword='.$project->title)->assertOk()->streamedContent();
        $this->assertStringNotContainsString($project->title, $csv);
        $this->assertSame(0, OperationLog::where('action', 'project.exported')->latest('id')->first()->payload['count']);
    }

    public function test_automatic_department_assignment_is_enforced_by_every_endpoint(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject('department');
        Sanctum::actingAs($outsider);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('total', 0);
        $this->getJson('/api/projects/options')->assertOk()->assertExactJson([]);
        $this->assertStringNotContainsString($project->title, $this->get('/api/projects/export.csv')->assertOk()->streamedContent());
        Sanctum::actingAs($assigned);
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('data.0.id', $project->id);
    }

    public function test_dispatch_filter_precedes_pagination_and_option_limit(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject();
        Project::factory()->count(22)->create([
            'unit_id' => $project->unit_id, 'owner_id' => $project->owner_id,
            'status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => 'expert',
            'metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
                'auto_assign' => true, 'assigned_user_ids' => [(string) $outsider->id],
            ]]]],
        ]);
        Sanctum::actingAs($assigned);
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('total', 1)->assertJsonPath('data.0.id', $project->id);
        $this->getJson('/api/projects?page=2')->assertOk()->assertJsonPath('total', 1)->assertJsonPath('data', []);
        $this->getJson('/api/projects/options?limit=1')->assertOk()->assertJsonCount(1)->assertJsonPath('0.id', $project->id);
    }

    public function test_historical_review_retains_access_after_return_and_reassignment(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject();
        ProjectReview::create(['project_id' => $project->id, 'reviewer_id' => $outsider->id,
            'stage' => 'expert', 'decision' => 'accept', 'reviewed_at' => now()->subDays(2)]);
        ProjectReview::create(['project_id' => $project->id, 'reviewer_id' => $assigned->id,
            'stage' => 'expert', 'decision' => 'return', 'reviewed_at' => now()->subDay()]);
        $project->update(['current_reviewer_role' => 'admin']);
        Sanctum::actingAs($outsider);
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->getJson('/api/projects/options')->assertOk()->assertJsonPath('0.id', $project->id);
        $this->assertStringContainsString($project->title, $this->get('/api/projects/export.csv')->assertOk()->streamedContent());
    }

    public function test_unit_colleague_sees_own_unit_draft_not_foreign_unit_draft(): void
    {
        [$project] = $this->assignedProject();
        $project->update(['status' => Project::STATUS_DRAFT]);
        $colleague = User::factory()->create(['role' => 'unit', 'unit_id' => $project->unit_id]);
        $foreignUnit = Unit::factory()->create();
        $foreignOwner = User::factory()->create(['role' => 'unit', 'unit_id' => $foreignUnit->id]);
        $foreign = Project::factory()->create(['unit_id' => $foreignUnit->id, 'owner_id' => $foreignOwner->id, 'status' => Project::STATUS_DRAFT]);
        Sanctum::actingAs($colleague);
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects/'.$foreign->id)->assertForbidden();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('total', 1);
        $this->getJson('/api/projects/options')->assertOk()->assertJsonCount(1)->assertJsonPath('0.id', $project->id);
        $csv = $this->get('/api/projects/export.csv')->assertOk()->streamedContent();
        $this->assertStringContainsString($project->title, $csv);
        $this->assertStringNotContainsString($foreign->title, $csv);
    }

    private function assignedProject(string $stage = 'expert'): array
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $assigned = User::factory()->create(['role' => $stage]);
        $outsider = User::factory()->create(['role' => $stage]);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id, 'title' => 'QA126-BOUNDARY',
            'status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => $stage,
            'metadata' => ['review_dispatch' => ['assignments' => [$stage => [
                'auto_assign' => true, 'assigned_user_ids' => [(string) $assigned->id],
            ]]]],
        ]);

        return [$project, $assigned, $outsider];
    }

    public function test_snapshotless_expert_reads_are_stable_and_do_not_write_assignments(): void
    {
        [$project, $expert] = $this->assignedProject();
        User::factory()->count(2)->create(['role' => 'expert']);
        $project->update(['metadata' => ['sentinel' => 'legacy']]);
        $snapshot = $project->refresh()->getRawOriginal();
        $preview = app(ReviewDispatchMatcher::class)->previewAssignment($project, 'expert');
        $expert = User::findOrFail($preview['assigned_user_ids'][0]);
        Sanctum::actingAs($expert);
        $first = $this->getJson('/api/projects/options')->assertOk()->json();
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->assertStringContainsString($project->title, $this->get('/api/projects/export.csv')->assertOk()->streamedContent());
        $this->assertSame($first, $this->getJson('/api/projects/options')->assertOk()->json());
        $this->assertSame($snapshot, $project->refresh()->getRawOriginal());
    }

    public function test_empty_expert_assignment_denies_every_endpoint(): void
    {
        [$project, $expert] = $this->assignedProject();
        $project->update(['metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
            'auto_assign' => true, 'assigned_user_ids' => [],
        ]]]]]);
        Sanctum::actingAs($expert);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->getJson('/api/projects')->assertOk()->assertJsonPath('total', 0);
        $this->getJson('/api/projects/options')->assertOk()->assertExactJson([]);
        $this->assertStringNotContainsString($project->title, $this->get('/api/projects/export.csv')->assertOk()->streamedContent());
    }

    public function test_legacy_category_rule_uses_same_expert_scope_for_options_and_detail(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject();
        User::factory()->create(['role' => 'expert']);
        $project->update(['metadata' => []]);
        ReviewDispatchRule::create([
            'name' => 'QA128 restricted legacy rule', 'target_stage' => 'expert',
            'project_category' => $project->category, 'project_type' => $project->project_type,
            'recommended_user_ids' => [$assigned->id], 'expert_count' => 1,
            'auto_assign' => true, 'is_active' => true, 'priority' => 1,
        ]);
        Sanctum::actingAs($outsider);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->getJson('/api/projects/options')->assertOk()->assertExactJson([]);
        Sanctum::actingAs($assigned);
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects/options')->assertOk()->assertJsonPath('0.id', $project->id);
    }

    public function test_metadata_only_test_batch_never_exposes_legacy_project_to_formal_pool(): void
    {
        [$project, $formal] = $this->assignedProject();
        User::factory()->count(2)->create(['role' => 'expert']);
        $testExperts = User::factory()->count(3)->create(['role' => 'expert', 'metadata' => ['e2e' => true]]);
        $batch = ApplicationBatch::create(['name' => 'Metadata batch', 'code' => 'QA128-META', 'status' => 'open', 'metadata' => ['e2e' => true]]);
        $project->update(['metadata' => [], 'application_batch_id' => $batch->id]);
        Sanctum::actingAs($formal);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->getJson('/api/projects/options')->assertOk()->assertExactJson([]);
        Sanctum::actingAs($testExperts->first());
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->getJson('/api/projects/options')->assertOk()->assertJsonPath('0.id', $project->id);
    }

    public function test_department_advisory_and_empty_automatic_fallback_remain_visible(): void
    {
        [$project, $assigned, $outsider] = $this->assignedProject('department');
        Sanctum::actingAs($outsider);
        foreach ([['auto_assign' => false, 'assigned_user_ids' => [$assigned->id]],
            ['auto_assign' => true, 'assigned_user_ids' => []]] as $assignment) {
            $project->update(['metadata' => ['review_dispatch' => ['assignments' => ['department' => $assignment]]]]);
            $this->getJson('/api/projects/'.$project->id)->assertOk();
            $this->getJson('/api/projects')->assertOk()->assertJsonPath('data.0.id', $project->id);
            $this->getJson('/api/projects/options')->assertOk()->assertJsonPath('0.id', $project->id);
            $this->assertStringContainsString($project->title, $this->get('/api/projects/export.csv')->assertOk()->streamedContent());
        }
    }

    public function test_revoked_project_permission_denies_all_entry_points(): void
    {
        [$project, $expert] = $this->assignedProject();
        $role = RbacRole::create(['code' => 'expert', 'name' => 'Expert', 'is_builtin' => true, 'is_active' => true]);
        Sanctum::actingAs($expert);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->getJson('/api/projects')->assertForbidden();
        $this->getJson('/api/projects/options')->assertForbidden();
        $this->get('/api/projects/export.csv')->assertForbidden();
        $this->assertSame(0, OperationLog::where('action', 'project.exported')->count());
    }

    public function test_county_export_excludes_project_outside_its_review_scope(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $county = User::factory()->create(['role' => 'county']);
        $visible = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'title' => 'QA124-COUNTY-ALLOWED', 'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'county',
        ]);
        $hidden = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'title' => 'QA124-DEPARTMENT-PRIVATE', 'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'department',
        ]);
        Sanctum::actingAs($county);
        $ids = collect($this->getJson('/api/projects')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($visible->id));
        $this->assertFalse($ids->contains($hidden->id));
        $this->getJson('/api/projects/'.$hidden->id)->assertForbidden();
        $csv = $this->get('/api/projects/export.csv')->assertOk()->streamedContent();
        $this->assertStringContainsString($visible->title, $csv);
        $this->assertStringNotContainsString($hidden->title, $csv);
    }

    public function test_unassigned_expert_cannot_export_automatic_assignment_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $assigned = User::factory()->create(['role' => 'expert']);
        $outsider = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'title' => 'QA124-ASSIGNED-EXPERT-ONLY',
            'status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => 'expert',
            'metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
                'stage' => 'expert', 'auto_assign' => true, 'assigned_user_ids' => [$assigned->id],
            ]]]],
        ]);
        Sanctum::actingAs($outsider);
        $this->getJson('/api/projects/'.$project->id)->assertForbidden();
        $this->assertNotContains($project->id, collect($this->getJson('/api/projects')
            ->assertOk()->json('data'))->pluck('id')->all());
        $this->assertNotContains($project->id, collect($this->getJson('/api/projects/options')
            ->assertOk()->json())->pluck('id')->all());
        $csv = $this->get('/api/projects/export.csv?keyword='.$project->title)
            ->assertOk()->streamedContent();
        $this->assertStringNotContainsString($project->title, $csv);
    }

    public function test_assigned_expert_can_list_select_and_export_its_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $expert = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'title' => 'QA124-ALLOWED-ASSIGNMENT',
            'status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => 'expert',
            'metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
                'stage' => 'expert', 'auto_assign' => true, 'assigned_user_ids' => [$expert->id],
            ]]]],
        ]);
        Sanctum::actingAs($expert);
        $this->getJson('/api/projects/'.$project->id)->assertOk();
        $this->assertContains($project->id, collect($this->getJson('/api/projects')
            ->assertOk()->json('data'))->pluck('id')->all());
        $this->assertContains($project->id, collect($this->getJson('/api/projects/options')
            ->assertOk()->json())->pluck('id')->all());
        $this->assertStringContainsString($project->title, $this->get('/api/projects/export.csv')
            ->assertOk()->streamedContent());
    }

    public function test_admin_export_excludes_drafts_but_super_admin_can_export_them(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $draft = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'title' => 'QA124-DRAFT', 'status' => Project::STATUS_DRAFT,
        ]);
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));
        $this->assertStringNotContainsString($draft->title, $this->get('/api/projects/export.csv?status=draft')
            ->assertOk()->streamedContent());
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        $this->assertStringContainsString($draft->title, $this->get('/api/projects/export.csv?status=draft')
            ->assertOk()->streamedContent());
    }
}
