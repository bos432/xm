<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectFile;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_cannot_create_or_submit_unit_project(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_DRAFT,
        ]);

        Sanctum::actingAs($admin);

        $this->postJson('/api/projects', [
            'title' => '管理员代填项目',
        ])->assertForbidden();

        $this->postJson("/api/projects/{$project->id}/submit")->assertForbidden();
    }

    public function test_reviewer_cannot_change_unit_project_application(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $countyReviewer = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_DRAFT,
        ]);

        Sanctum::actingAs($countyReviewer);

        $this->putJson("/api/projects/{$project->id}", [
            'title' => '审核员越权修改',
        ])->assertForbidden();
        $this->deleteJson("/api/projects/{$project->id}")->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/submit")->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/withdraw")->assertForbidden();
    }

    public function test_non_unit_users_cannot_upload_or_delete_project_files(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $owner->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/budget.pdf',
            'original_name' => 'budget.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'budget'),
            'purpose' => 'application',
        ]);
        Storage::disk('local')->put($file->path, 'budget');

        Sanctum::actingAs($admin);

        $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('admin.pdf', 12, 'application/pdf'),
        ])->assertForbidden();
        $this->deleteJson("/api/files/{$file->id}")->assertForbidden();
    }

    public function test_admin_can_view_all_projects_but_unit_list_is_scoped(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $unitUser = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $ownProject = Project::factory()->create(['unit_id' => $ownUnit->id, 'owner_id' => $unitUser->id, 'status' => Project::STATUS_SUBMITTED]);
        $otherProject = Project::factory()->create(['unit_id' => $otherUnit->id, 'owner_id' => $otherOwner->id, 'status' => Project::STATUS_SUBMITTED]);
        $draftProject = Project::factory()->create(['unit_id' => $ownUnit->id, 'owner_id' => $unitUser->id, 'status' => Project::STATUS_DRAFT]);

        Sanctum::actingAs($admin);
        $adminIds = collect($this->getJson('/api/projects')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($adminIds->contains($ownProject->id));
        $this->assertTrue($adminIds->contains($otherProject->id));
        $this->assertFalse($adminIds->contains($draftProject->id));

        Sanctum::actingAs($unitUser);
        $unitIds = collect($this->getJson('/api/projects')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($unitIds->contains($ownProject->id));
        $this->assertFalse($unitIds->contains($otherProject->id));
    }

    public function test_project_list_keyword_filter_stays_scoped_to_unit(): void
    {
        $ownUnit = Unit::factory()->create(['name' => '东城创新单位']);
        $otherUnit = Unit::factory()->create(['name' => '西城创新单位']);
        $unitUser = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit', 'username' => 'east-owner']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit', 'username' => 'west-owner']);
        $ownProject = Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $unitUser->id,
            'title' => '智能制造项目',
        ]);
        Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $otherOwner->id,
            'title' => '智能制造越权项目',
        ]);
        Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $unitUser->id,
            'title' => '普通服务项目',
        ]);

        Sanctum::actingAs($unitUser);

        $ids = collect($this->getJson('/api/projects?keyword=' . urlencode('智能制造'))->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($ownProject->id));
        $this->assertCount(1, $ids);
    }

    public function test_project_list_can_filter_by_category_and_type(): void
    {
        $unit = Unit::factory()->create();
        $unitUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $matched = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $unitUser->id,
            'title' => '科技重点项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $unitUser->id,
            'title' => '产业示范项目',
            'category' => '产业项目',
            'project_type' => '创新示范',
        ]);

        Sanctum::actingAs($unitUser);

        $ids = collect($this->getJson('/api/projects?category=' . urlencode('科技项目') . '&project_type=' . urlencode('重点扶持'))->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($matched->id));
        $this->assertCount(1, $ids);
    }
}
