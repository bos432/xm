<?php

namespace Tests\Feature;

use App\Models\AcceptanceApplication;
use App\Models\AcceptanceExtension;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AcceptanceReviewAtomicityTest extends TestCase
{
    use RefreshDatabase;

    public function test_failed_final_review_audit_rolls_back_review_and_project_closure(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id, 'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $acceptance = AcceptanceApplication::create([
            'project_id' => $project->id, 'unit_id' => $unit->id, 'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_REVIEWING, 'current_reviewer_role' => 'admin',
        ]);
        $beforeProject = $project->refresh()->getRawOriginal();
        $beforeAcceptance = $acceptance->refresh()->getRawOriginal();
        OperationLog::creating(function (): void {
            throw new \RuntimeException('QA acceptance audit failure');
        });
        Sanctum::actingAs($admin);
        $this->withoutExceptionHandling();
        try {
            $this->postJson('/api/acceptance/'.$acceptance->id.'/reviews', ['decision' => 'close']);
            $this->fail('Audit failure must not commit final acceptance');
        } catch (\RuntimeException $exception) {
            $this->assertSame('QA acceptance audit failure', $exception->getMessage());
        } finally {
            OperationLog::flushEventListeners();
        }
        $this->assertSame($beforeProject, $project->refresh()->getRawOriginal());
        $this->assertSame($beforeAcceptance, $acceptance->refresh()->getRawOriginal());
        $this->assertDatabaseCount('acceptance_reviews', 0);
        $this->assertDatabaseCount('operation_logs', 0);
        $this->assertDatabaseCount('messages', 0);
    }

    public function test_failed_extension_audit_rolls_back_decision_and_notification(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id, 'status' => Project::STATUS_ACCEPTANCE,
        ]);
        $acceptance = AcceptanceApplication::create([
            'project_id' => $project->id, 'unit_id' => $unit->id, 'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_REVIEWING, 'current_reviewer_role' => 'admin',
        ]);
        $extension = AcceptanceExtension::create([
            'acceptance_application_id' => $acceptance->id, 'project_id' => $project->id,
            'requested_by' => $owner->id, 'status' => 'pending', 'reason' => 'QA rollback',
        ]);
        OperationLog::creating(function (): void {
            throw new \RuntimeException('QA extension audit failure');
        });
        Sanctum::actingAs($admin);
        $this->withoutExceptionHandling();
        try {
            $this->postJson('/api/acceptance/'.$acceptance->id.'/extensions', [
                'extension_id' => $extension->id, 'decision' => 'approved',
            ]);
            $this->fail('Audit failure must not commit extension decision');
        } catch (\RuntimeException $exception) {
            $this->assertSame('QA extension audit failure', $exception->getMessage());
        } finally {
            OperationLog::flushEventListeners();
        }
        $this->assertSame('pending', $extension->refresh()->status);
        $this->assertNull($extension->reviewed_by);
        $this->assertNull($extension->reviewed_at);
        $this->assertNull($extension->review_comment);
        $this->assertDatabaseCount('operation_logs', 0);
        $this->assertDatabaseCount('messages', 0);
    }
}
