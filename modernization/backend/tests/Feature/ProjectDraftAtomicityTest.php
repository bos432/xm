<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ProjectDraftAtomicityTest extends TestCase
{
    use RefreshDatabase;

    public static function actions(): array
    {
        return [['update'], ['submit']];
    }

    private function draft(): Project
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $batch = ApplicationBatch::create([
            'name' => 'QA atomic draft batch', 'code' => 'QA-ATOMIC-DRAFT',
            'status' => 'open', 'starts_at' => now()->subDay(), 'ends_at' => now()->addDay(),
        ]);
        Sanctum::actingAs($owner);

        return Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'application_batch_id' => $batch->id, 'status' => 'draft',
            'title' => 'Original applicant contents',
        ]);
    }

    #[DataProvider('actions')]
    public function test_stale_route_binding_cannot_edit_or_resubmit_after_submission(string $action): void
    {
        $project = $this->draft();
        $entered = false;
        Project::retrieved(function (Project $bound) use ($project, &$entered): void {
            if ($entered || $bound->id !== $project->id) {
                return;
            }
            $entered = true;
            Project::query()->whereKey($project->id)->update([
                'status' => 'submitted', 'current_reviewer_role' => 'county', 'submitted_at' => now(),
            ]);
        });
        try {
            $response = $action === 'update'
                ? $this->putJson('/api/projects/'.$project->id, ['title' => 'Stale edit'])
                : $this->postJson('/api/projects/'.$project->id.'/submit');
            $response->assertStatus(422);
        } finally {
            Project::flushEventListeners();
        }
        $this->assertTrue($entered, 'Route binding must exercise the stale snapshot');
        $this->assertSame('Original applicant contents', $project->fresh()->title);
        $this->assertSame('submitted', $project->fresh()->status);
        $this->assertDatabaseCount('operation_logs', 0);
        $this->assertDatabaseCount('messages', 0);
    }

    #[DataProvider('actions')]
    public function test_audit_failure_rolls_back_draft_edit_or_submission(string $action): void
    {
        $project = $this->draft();
        $before = $project->refresh()->getRawOriginal();
        OperationLog::creating(function (): void {
            throw new \RuntimeException('QA draft audit failure');
        });
        $this->withoutExceptionHandling();
        try {
            if ($action === 'update') {
                $this->putJson('/api/projects/'.$project->id, ['title' => 'Must roll back']);
            } else {
                $this->postJson('/api/projects/'.$project->id.'/submit');
            }
            $this->fail('Audit failure must abort the state change');
        } catch (\RuntimeException $error) {
            $this->assertSame('QA draft audit failure', $error->getMessage());
        } finally {
            OperationLog::flushEventListeners();
        }
        $this->assertSame($before, $project->fresh()->getRawOriginal());
        $this->assertDatabaseCount('operation_logs', 0);
        $this->assertDatabaseCount('messages', 0);
    }
}
