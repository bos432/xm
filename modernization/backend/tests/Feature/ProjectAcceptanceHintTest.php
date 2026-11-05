<?php

namespace Tests\Feature;

use App\Models\AcceptanceApplication;
use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectAcceptanceHintTest extends TestCase
{
    use RefreshDatabase;

    public function test_all_authorized_roles_get_actionable_acceptance_hints_without_reopening_submission_review(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
        $project = Project::factory()->create([
            'unit_id' => $unit->id, 'owner_id' => $owner->id,
            'status' => Project::STATUS_ACCEPTANCE, 'current_reviewer_role' => null,
        ]);
        $acceptance = AcceptanceApplication::create([
            'project_id' => $project->id, 'unit_id' => $unit->id, 'submitted_by' => $owner->id,
            'status' => AcceptanceApplication::STATUS_SUBMITTED, 'current_reviewer_role' => 'department',
            'submitted_at' => now(),
        ]);

        foreach (['unit', 'county', 'department', 'expert', 'admin', 'super_admin'] as $role) {
            $user = $role === 'unit' ? $owner : User::factory()->create(['role' => $role]);
            if (in_array($role, ['county', 'department', 'expert'], true)) {
                ProjectReview::create([
                    'project_id' => $project->id, 'reviewer_id' => $user->id, 'stage' => $role,
                    'decision' => 'approve', 'reviewed_at' => now(),
                ]);
            }
            Sanctum::actingAs($user);
            $hint = $this->getJson('/api/projects/'.$project->id)->assertOk()->json('next_step');
            $this->assertSame('当前：项目验收中', $hint['title']);
            $this->assertSame('/acceptance', $hint['path']);
            $this->assertStringContainsString('部门审核', $hint['body']);
            $this->assertStringNotContainsString('发起验收', $hint['body']);
        }

        Sanctum::actingAs($owner);
        $acceptance->update(['status' => AcceptanceApplication::STATUS_RETURNED, 'current_reviewer_role' => null]);
        $this->getJson('/api/projects/'.$project->id)->assertOk()
            ->assertJsonPath('next_step.body', '下一步：进入“验收管理”，按退回意见补充材料后重新提交验收。');
        $acceptance->update(['status' => AcceptanceApplication::STATUS_DRAFT]);
        $this->getJson('/api/projects/'.$project->id)->assertOk()
            ->assertJsonPath('next_step.body', '下一步：进入“验收管理”，上传材料并提交已有的验收草稿。');
    }
}
