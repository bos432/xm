<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class E2eBatchSubmissionBoundaryTest extends TestCase
{
    use RefreshDatabase;

    public static function submissionCases(): array
    {
        return [
            'ordinary applicant denied' => [false, false, 'open', 'current', false, 422],
            'legacy dedicated applicant allowed' => [true, false, 'open', 'current', false, 200],
            'metadata dedicated applicant allowed' => [false, true, 'open', 'current', false, 200],
            'expired batch denied' => [true, false, 'open', 'past', false, 422],
            'future batch denied' => [true, false, 'open', 'future', false, 422],
            'closed batch denied' => [true, false, 'closed', 'current', false, 422],
            'archived batch denied' => [true, false, 'archived', 'current', false, 422],
            'history batch denied even if marked e2e' => [true, true, 'open', 'current', true, 422],
        ];
    }

    #[DataProvider('submissionCases')]
    public function test_submission_does_not_bypass_batch_boundaries(
        bool $legacyName,
        bool $e2eMetadata,
        string $status,
        string $window,
        bool $history,
        int $expectedStatus,
    ): void {
        $unit = Unit::factory()->create();
        $user = User::factory()->create([
            'username' => $legacyName ? 'e2e_20261016ops_unit' : 'ordinary-unit',
            'role' => 'unit',
            'unit_id' => $unit->id,
            'metadata' => ['e2e' => $e2eMetadata],
        ]);
        $attributes = [
            'name' => 'E2E-BOUNDARY',
            'code' => 'E2E-BOUNDARY',
            'status' => $status,
            'starts_at' => $window === 'future' ? now()->addDay() : now()->subDays(2),
            'ends_at' => $window === 'past' ? now()->subDay() : now()->addDays(2),
            'metadata' => ['e2e' => true],
        ];
        if ($history) {
            $batch = ApplicationBatch::where('code', ApplicationBatch::HISTORY_DEFAULT_CODE)->firstOrFail();
            unset($attributes['code']);
            $batch->update($attributes);
        } else {
            $batch = ApplicationBatch::create($attributes);
        }
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'application_batch_id' => $batch->id,
            'status' => Project::STATUS_DRAFT,
            'current_reviewer_role' => null,
            'submitted_at' => null,
        ]);
        Sanctum::actingAs($user);

        $this->postJson("/api/projects/{$project->id}/submit")->assertStatus($expectedStatus);

        $project->refresh();
        $this->assertSame($batch->id, $project->application_batch_id);
        $this->assertSame($expectedStatus === 200 ? Project::STATUS_SUBMITTED : Project::STATUS_DRAFT, $project->status);
        $this->assertSame($expectedStatus === 200 ? 'county' : null, $project->current_reviewer_role);
        if ($expectedStatus !== 200) {
            $this->assertNull($project->submitted_at);
            $this->assertDatabaseMissing('operation_logs', [
                'action' => 'project.submitted',
                'target_id' => $project->id,
            ]);
        }
    }
}
