<?php

namespace Tests\Feature;

use App\Models\AcceptanceApplication;
use App\Models\AcceptanceExtension;
use App\Models\AcceptanceReview;
use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use App\Support\RuntimeConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AcceptanceConfigurationAndTimelineTest extends TestCase
{
    use RefreshDatabase;

    private function acceptance(string $stage = 'county'): AcceptanceApplication
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE,
        ]);

        return AcceptanceApplication::create([
            'project_id' => $project->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED,
            'current_reviewer_role' => $stage,
            'submitted_at' => now(),
        ]);
    }

    public function test_all_acceptance_stages_obey_score_switch_without_losing_unscored_review(): void
    {
        foreach (['county', 'department', 'expert', 'admin'] as $stage) {
            $acceptance = $this->acceptance($stage);
            Sanctum::actingAs(User::factory()->create(['role' => $stage]));
            RuntimeConfig::set('review.score_enabled.'.$stage, '0', 'review', false);

            $this->getJson('/api/acceptance/'.$acceptance->id)->assertOk()
                ->assertJsonPath('review_config.score_enabled', false);
            $this->getJson('/api/acceptance?scope=pending')->assertOk()
                ->assertJsonPath('data.0.review_config.score_enabled', false);
            $count = AcceptanceReview::count();
            $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', [
                'decision' => 'approve', 'score' => 85,
            ])->assertUnprocessable()->assertJsonValidationErrors('score');
            $this->assertSame($count, AcceptanceReview::count());
            $this->assertSame($stage, $acceptance->fresh()->current_reviewer_role);

            $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', [
                'decision' => 'approve', 'score' => null,
            ])->assertCreated()->assertJsonPath('review.score', null);

            $scored = $this->acceptance($stage);
            RuntimeConfig::set('review.score_enabled.'.$stage, '1', 'review', false);
            $this->getJson('/api/acceptance/'.$scored->id)->assertOk()
                ->assertJsonPath('review_config.score_enabled', true);
            $this->postJson('/api/acceptance/'.$scored->id.'/reviews', [
                'decision' => 'approve', 'score' => 85,
            ])->assertCreated()->assertJsonPath('review.score', '85.00');
        }
    }

    public function test_resubmission_timeline_uses_current_round_and_preserves_history(): void
    {
        $acceptance = $this->acceptance();
        Sanctum::actingAs(User::factory()->create(['role' => 'county']));
        $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', ['decision' => 'approve'])->assertCreated();
        Sanctum::actingAs(User::factory()->create(['role' => 'department']));
        $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', ['decision' => 'return'])->assertCreated();
        $owner = $acceptance->project->owner;
        Sanctum::actingAs($owner);
        $this->postJson('/api/acceptance/'.$acceptance->id.'/submit')->assertOk();

        $detail = $this->getJson('/api/acceptance/'.$acceptance->id)->assertOk()->assertJsonCount(2, 'reviews');
        $stages = collect($detail->json('timeline'))->keyBy('key');
        $this->assertSame('current', $stages['county']['status']);
        $this->assertNull($stages['county']['decision']);
        $this->assertSame('pending', $stages['department']['status']);
        $this->assertNull($stages['department']['decision']);

        Sanctum::actingAs(User::factory()->create(['role' => 'county']));
        $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', ['decision' => 'approve'])->assertCreated();
        Sanctum::actingAs($owner);
        $detail = $this->getJson('/api/acceptance/'.$acceptance->id)->assertOk()->assertJsonCount(3, 'reviews');
        $stages = collect($detail->json('timeline'))->keyBy('key');
        $this->assertSame('done', $stages['county']['status']);
        $this->assertSame('approve', $stages['county']['decision']);
        $this->assertSame('current', $stages['department']['status']);
        $this->assertNull($stages['department']['decision']);
    }

    public function test_extension_plan_serializes_as_calendar_date_instead_of_utc_timestamp(): void
    {
        config(['app.timezone' => 'Asia/Shanghai']);
        $acceptance = $this->acceptance();
        Sanctum::actingAs($acceptance->project->owner);
        $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
            'reason' => 'Synthetic schedule change', 'expected_date' => '2026-12-31',
        ])->assertCreated()->assertJsonPath('expected_date', '2026-12-31');
        $this->getJson('/api/acceptance/'.$acceptance->id)->assertOk()
            ->assertJsonPath('extensions.0.expected_date', '2026-12-31');
    }

    public function test_terminal_acceptance_cannot_create_new_extension_but_keeps_history_visible(): void
    {
        foreach (['approved', 'closed', 'rejected'] as $status) {
            $acceptance = $this->acceptance();
            $acceptance->update(['status' => $status, 'current_reviewer_role' => null]);
            $extension = AcceptanceExtension::create([
                'acceptance_application_id' => $acceptance->id, 'project_id' => $acceptance->project_id,
                'requested_by' => $acceptance->submitted_by, 'reason' => 'Prior schedule request',
                'status' => 'approved', 'expected_date' => '2026-12-31',
            ]);
            Sanctum::actingAs($acceptance->project->owner);
            $before = AcceptanceExtension::count();
            $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
                'reason' => 'Must not reopen completed acceptance', 'expected_date' => '2027-01-31',
            ])->assertUnprocessable();
            $this->assertSame($before, AcceptanceExtension::count());
            $this->getJson('/api/acceptance/'.$acceptance->id)->assertOk()
                ->assertJsonCount(1, 'extensions')->assertJsonPath('extensions.0.id', $extension->id);
        }
    }

    public function test_extension_decision_is_final_and_duplicate_processing_cannot_overwrite_it(): void
    {
        $acceptance = $this->acceptance();
        Sanctum::actingAs($acceptance->project->owner);
        $id = $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
            'reason' => 'Schedule request', 'expected_date' => '2026-12-31',
        ])->assertCreated()->json('id');
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
            'extension_id' => $id, 'decision' => 'approved', 'comment' => 'Original approval',
        ])->assertOk();
        $before = AcceptanceExtension::findOrFail($id)->getAttributes();
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
            'extension_id' => $id, 'decision' => 'rejected', 'comment' => 'Stale conflicting decision',
        ])->assertUnprocessable();
        $this->assertSame($before, AcceptanceExtension::findOrFail($id)->getAttributes());
    }
}
