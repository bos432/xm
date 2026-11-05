<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LifecycleActionRegressionTest extends TestCase
{
    use RefreshDatabase;

    private function actors(): array
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $otherUnit = Unit::factory()->create();
        $other = User::factory()->create(['role' => 'unit', 'unit_id' => $otherUnit->id]);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id, 'status' => Project::STATUS_APPROVED]);

        return [$owner, $other, $admin, $project];
    }

    public function test_task_book_and_progress_return_edit_resubmit_approve_and_finality(): void
    {
        [$owner, $other, $admin, $project] = $this->actors();
        foreach ([['task-books', ['title' => 'QA task', 'content' => '<p>Plan</p>']],
            ['progress', ['period' => 'QA period', 'summary' => '<p>Progress</p>', 'issues' => 'None', 'next_plan' => 'Next']]] as [$path, $payload]) {
            Sanctum::actingAs($owner);
            $id = $this->postJson('/api/projects/'.$project->id.'/'.$path, $payload)->assertCreated()->assertJsonPath('status', 'draft')->json('id');
            $base = '/api/lifecycle/'.$path.'/'.$id;
            Sanctum::actingAs($other);
            $this->putJson($base, $payload)->assertForbidden();
            $this->postJson($base.'/submit')->assertForbidden();
            $this->getJson('/api/lifecycle/'.$path.'?project_id='.$project->id)->assertOk()->assertJsonPath('total', 0);
            Sanctum::actingAs($admin);
            $this->postJson($base.'/review', ['decision' => 'approve'])->assertUnprocessable();
            Sanctum::actingAs($owner);
            $this->postJson($base.'/submit')->assertOk()->assertJsonPath('status', 'submitted');
            $this->postJson($base.'/submit')->assertUnprocessable();
            $this->putJson($base, $payload)->assertUnprocessable();
            Sanctum::actingAs($admin);
            $this->postJson($base.'/review', ['decision' => 'return', 'comment' => '<p>Revise</p>'])->assertOk()->assertJsonPath('status', 'returned');
            Sanctum::actingAs($owner);
            $this->putJson($base, $payload)->assertOk();
            $this->postJson($base.'/submit')->assertOk()->assertJsonPath('status', 'submitted');
            Sanctum::actingAs($admin);
            $approved = $this->postJson($base.'/review', ['decision' => 'approve', 'comment' => 'Final'])->assertOk()->assertJsonPath('status', 'approved')->json();
            $this->postJson($base.'/review', ['decision' => 'reject', 'comment' => 'Overwrite'])->assertUnprocessable();
            $this->getJson('/api/lifecycle/'.$path.'?project_id='.$project->id.'&status=approved&keyword=QA')->assertOk()
                ->assertJsonPath('total', 1)->assertJsonPath('data.0.review_comment', $approved['review_comment']);
            Sanctum::actingAs($owner);
            $this->putJson($base, $payload)->assertUnprocessable();
            $this->postJson($base.'/submit')->assertUnprocessable();
        }
    }

    public function test_rectification_response_return_resubmit_and_terminal_protection(): void
    {
        [$owner, $other, $admin, $project] = $this->actors();
        Sanctum::actingAs($owner);
        $this->postJson('/api/projects/'.$project->id.'/rectifications', ['title' => 'QA correction'])->assertForbidden();
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/projects/'.$project->id.'/rectifications', ['title' => 'QA correction', 'requirement' => '<p>Evidence</p>'])
            ->assertCreated()->assertJsonPath('status', 'pending')->json('id');
        $base = '/api/lifecycle/rectifications/'.$id;
        $this->postJson($base.'/review', ['decision' => 'approve'])->assertUnprocessable();
        Sanctum::actingAs($other);
        $this->postJson($base.'/submit', ['response' => 'Forged'])->assertForbidden();
        Sanctum::actingAs($owner);
        $this->postJson($base.'/submit', ['response' => ''])->assertUnprocessable();
        $this->postJson($base.'/submit', ['response' => '<p>First</p>'])->assertOk()->assertJsonPath('status', 'submitted');
        $this->postJson($base.'/submit', ['response' => 'Repeat'])->assertUnprocessable();
        Sanctum::actingAs($admin);
        $this->postJson($base.'/review', ['decision' => 'return'])->assertOk()->assertJsonPath('status', 'returned');
        Sanctum::actingAs($owner);
        $this->postJson($base.'/submit', ['response' => '<p>Revised</p>'])->assertOk();
        Sanctum::actingAs($admin);
        $this->postJson($base.'/review', ['decision' => 'approve'])->assertOk()->assertJsonPath('status', 'approved');
        $this->postJson($base.'/review', ['decision' => 'reject'])->assertUnprocessable();
        Sanctum::actingAs($owner);
        $this->postJson($base.'/submit', ['response' => 'Overwrite'])->assertUnprocessable();
        $this->getJson('/api/lifecycle/rectifications?status=approved&keyword=QA')->assertOk()->assertJsonPath('total', 1);
    }

    public function test_invalid_fields_and_inactive_units_do_not_create_lifecycle_records(): void
    {
        [$owner, $other, $admin, $project] = $this->actors();
        Sanctum::actingAs($owner);
        $this->postJson('/api/projects/'.$project->id.'/task-books', ['title' => str_repeat('x', 201)])
            ->assertUnprocessable()->assertJsonValidationErrors('title');
        $this->postJson('/api/projects/'.$project->id.'/progress', ['summary' => str_repeat('x', 20001), 'progress_date' => 'invalid'])
            ->assertUnprocessable()->assertJsonValidationErrors(['summary', 'progress_date']);
        $owner->unit()->update(['status' => 'inactive']);
        $owner->unsetRelation('unit');
        $this->postJson('/api/projects/'.$project->id.'/task-books', ['title' => 'Blocked'])->assertForbidden();
        $this->postJson('/api/projects/'.$project->id.'/progress', ['summary' => 'Blocked'])->assertForbidden();
        $this->assertDatabaseCount('project_task_books', 0);
        $this->assertDatabaseCount('project_progress_records', 0);
        Sanctum::actingAs($admin);
        $this->postJson('/api/projects/'.$project->id.'/rectifications', ['title' => '', 'due_date' => 'invalid'])
            ->assertUnprocessable()->assertJsonValidationErrors(['title', 'due_date']);
        $this->assertDatabaseCount('project_rectifications', 0);
    }
}
