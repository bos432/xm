<?php

namespace Tests\Feature;

use App\Models\ExpertCertification;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\ProjectFile;
use App\Models\ProjectProgressRecord;
use App\Models\ProjectTaskBook;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectLifecycleManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_user_can_delete_draft_project_with_audit_log(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/draft-budget.pdf',
            'original_name' => 'draft-budget.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'draft-budget'),
            'purpose' => 'application',
        ]);
        Storage::disk('local')->put($file->path, 'draft-budget');

        Sanctum::actingAs($user);

        $this->deleteJson("/api/projects/{$project->id}")->assertNoContent();
        Storage::disk('local')->assertMissing($file->path);
        $this->assertDatabaseMissing('projects', ['id' => $project->id]);
        $this->assertDatabaseMissing('project_files', ['id' => $file->id]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project.deleted',
            'target_type' => Project::class,
            'target_id' => $project->id,
        ]);
    }

    public function test_draft_project_delete_skips_invalid_file_storage_records_with_audit_log(): void
    {
        Storage::fake('local');
        Storage::fake('public');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);
        $validFile = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/valid.pdf',
            'original_name' => 'valid.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'valid'),
            'purpose' => 'application',
        ]);
        $invalidFile = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'local',
            'path' => '../outside.pdf',
            'original_name' => 'outside.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'outside'),
            'purpose' => 'application',
        ]);
        $invalidDiskFile = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'public',
            'path' => 'project-files/'.$project->id.'/public.pdf',
            'original_name' => 'public.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'public'),
            'purpose' => 'application',
        ]);
        Storage::disk('public')->put($invalidDiskFile->path, 'public');
        Storage::disk('local')->put($validFile->path, 'valid');

        Sanctum::actingAs($user);

        $this->deleteJson("/api/projects/{$project->id}")->assertNoContent();
        Storage::disk('local')->assertMissing($validFile->path);
        $this->assertDatabaseMissing('projects', ['id' => $project->id]);
        $this->assertDatabaseMissing('project_files', ['id' => $validFile->id]);
        $this->assertDatabaseMissing('project_files', ['id' => $invalidFile->id]);
        $this->assertDatabaseMissing('project_files', ['id' => $invalidDiskFile->id]);
        Storage::disk('public')->assertExists($invalidDiskFile->path);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.invalid_path',
            'target_type' => ProjectFile::class,
            'target_id' => $invalidFile->id,
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.invalid_disk',
            'target_type' => ProjectFile::class,
            'target_id' => $invalidDiskFile->id,
        ]);

        $deleteLog = OperationLog::query()
            ->where('action', 'project.deleted')
            ->where('target_type', Project::class)
            ->where('target_id', $project->id)
            ->firstOrFail();
        $this->assertSame(1, $deleteLog->payload['deleted_file_count']);
        $this->assertSame(2, $deleteLog->payload['skipped_invalid_file_count']);
    }

    public function test_unit_user_can_delete_own_project_file_with_audit_log(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
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

        Sanctum::actingAs($user);

        $this->deleteJson("/api/files/{$file->id}")->assertNoContent();
        Storage::disk('local')->assertMissing($file->path);
        $this->assertDatabaseMissing('project_files', ['id' => $file->id]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.deleted',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
    }

    public function test_submitted_project_cannot_be_deleted(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_SUBMITTED,
        ]);

        Sanctum::actingAs($user);

        $this->deleteJson("/api/projects/{$project->id}")->assertUnprocessable();
        $this->assertDatabaseHas('projects', ['id' => $project->id]);
    }

    public function test_reviewers_only_list_lifecycle_items_for_their_own_tasks_or_reviews(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $reviewer = User::factory()->create(['role' => 'county']);
        $otherReviewer = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);
        $otherProject = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);

        ProjectTaskBook::create([
            'project_id' => $otherProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => 'submitted',
            'title' => '其他审核员待审任务书',
            'submitted_at' => now(),
        ]);
        $reviewedProgress = ProjectProgressRecord::create([
            'project_id' => $otherProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'reviewed_by' => $reviewer->id,
            'status' => 'approved',
            'summary' => '本人已处理进展',
        ]);
        ProjectProgressRecord::create([
            'project_id' => $project->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'reviewed_by' => $otherReviewer->id,
            'status' => 'approved',
            'summary' => '其他审核员已处理进展',
        ]);
        $reviewedBook = ProjectTaskBook::create([
            'project_id' => $otherProject->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'reviewed_by' => $reviewer->id,
            'status' => 'approved',
            'title' => '本人已处理任务书',
        ]);

        Sanctum::actingAs($reviewer);

        $taskBookIds = collect($this->getJson('/api/lifecycle/task-books')->assertOk()->json('data'))->pluck('id');
        $this->assertSame([$reviewedBook->id], $taskBookIds->all());
        $progressIds = collect($this->getJson('/api/lifecycle/progress')->assertOk()->json('data'))->pluck('id');
        $this->assertSame([$reviewedProgress->id], $progressIds->all());
    }

    public function test_expert_certifications_are_not_visible_to_units_or_unrelated_review_roles(): void
    {
        $expert = User::factory()->create(['role' => 'expert']);
        $otherExpert = User::factory()->create(['role' => 'expert']);
        $ownCertification = ExpertCertification::create([
            'user_id' => $expert->id,
            'submitted_by' => $expert->id,
            'status' => 'submitted',
            'specialty' => '本人材料',
        ]);
        ExpertCertification::create([
            'user_id' => $otherExpert->id,
            'submitted_by' => $otherExpert->id,
            'status' => 'submitted',
            'specialty' => '他人敏感材料',
        ]);

        Sanctum::actingAs($expert);
        $ids = collect($this->getJson('/api/lifecycle/expert-certifications')->assertOk()->json('data'))->pluck('id');
        $this->assertSame([$ownCertification->id], $ids->all());

        $unit = User::factory()->create(['role' => 'unit']);
        Sanctum::actingAs($unit);
        $this->getJson('/api/lifecycle/expert-certifications')->assertForbidden();
    }

    public function test_unit_can_only_view_own_expert_certification(): void
    {
        $unit = Unit::factory()->create();
        $expert = User::factory()->create(['unit_id' => $unit->id, 'role' => 'expert']);
        $otherExpert = User::factory()->create(['role' => 'expert']);
        $ownCertification = ExpertCertification::create([
            'user_id' => $expert->id,
            'submitted_by' => $expert->id,
            'status' => 'submitted',
            'specialty' => '本专家认证',
        ]);
        ExpertCertification::create([
            'user_id' => $otherExpert->id,
            'submitted_by' => $otherExpert->id,
            'status' => 'submitted',
            'specialty' => '其他专家认证',
        ]);

        Sanctum::actingAs($expert);

        $this->getJson('/api/lifecycle/expert-certifications')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $ownCertification->id);
        $this->postJson('/api/lifecycle/expert-certifications', [
            'specialty' => '新专业方向',
        ])->assertCreated();
    }

    public function test_county_and_department_reviewers_cannot_list_expert_certifications(): void
    {
        $county = User::factory()->create(['role' => 'county']);
        Sanctum::actingAs($county);
        $this->getJson('/api/lifecycle/expert-certifications')->assertForbidden();

        $department = User::factory()->create(['role' => 'department']);
        Sanctum::actingAs($department);
        $this->getJson('/api/lifecycle/expert-certifications')->assertForbidden();
    }

    public function test_lifecycle_record_detail_and_review_require_ownership_or_assignment(): void
    {
        $unit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $reviewer = User::factory()->create(['role' => 'admin']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $otherProject = Project::factory()->create(['unit_id' => $otherUnit->id, 'owner_id' => $otherOwner->id]);
        $record = ProjectProgressRecord::create([
            'project_id' => $otherProject->id,
            'unit_id' => $otherUnit->id,
            'submitted_by' => $otherOwner->id,
            'reviewed_by' => User::factory()->create(['role' => 'county'])->id,
            'status' => 'approved',
            'summary' => '不应被未参与审核员查看',
        ]);

        $reviewer->forceFill(['role' => 'county'])->save();
        $permissionCatalog = collect(\App\Support\Role::permissionsCatalog());
        $rolePermissionIds = $permissionCatalog->map(fn (array $item) => \App\Models\RbacPermission::query()->firstOrCreate(
            ['code' => $item['code']],
            ['name' => $item['name'], 'group' => $item['group']]
        )->id)->all();
        $role = \App\Models\RbacRole::query()->firstOrCreate(
            ['code' => 'county'],
            ['name' => '区县审核', 'is_builtin' => true, 'is_active' => true]
        );
        $role->permissions()->sync($rolePermissionIds);

        Sanctum::actingAs($reviewer);

        $this->getJson('/api/lifecycle/progress')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/lifecycle/progress/{$record->id}/review", [
            'decision' => 'approve',
        ])->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/lifecycle/progress/{$record->id}", [
            'summary' => '跨单位外的写操作',
        ])->assertForbidden();
    }

    public function test_reviewer_permission_exposes_submitted_lifecycle_queue_and_allows_review(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $reviewer = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);
        $record = ProjectProgressRecord::create([
            'project_id' => $project->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => 'submitted',
            'summary' => '待审核的进展',
        ]);
        $permissionCatalog = collect(\App\Support\Role::permissionsCatalog());
        $permissionIds = $permissionCatalog->map(fn (array $item) => \App\Models\RbacPermission::query()->firstOrCreate(
            ['code' => $item['code']],
            ['name' => $item['name'], 'group' => $item['group']]
        )->id)->all();
        $role = \App\Models\RbacRole::query()->firstOrCreate(
            ['code' => 'county'],
            ['name' => '区县审核', 'is_builtin' => true, 'is_active' => true]
        );
        $role->permissions()->sync($permissionIds);

        $unrelatedSubmitted = ProjectProgressRecord::create([
            'project_id' => Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id])->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'status' => 'submitted',
            'summary' => '另一条待审核进展',
        ]);

        Sanctum::actingAs($reviewer);

        $this->getJson('/api/lifecycle/progress')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['id' => $record->id])
            ->assertJsonFragment(['id' => $unrelatedSubmitted->id]);
        $this->postJson("/api/lifecycle/progress/{$record->id}/review", [
            'decision' => 'approve',
        ])->assertOk();
    }

    public function test_reviewer_cannot_review_or_list_another_reviewers_completed_lifecycle_record(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $reviewer = User::factory()->create(['role' => 'county']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id]);
        $record = ProjectProgressRecord::create([
            'project_id' => $project->id,
            'unit_id' => $unit->id,
            'submitted_by' => $owner->id,
            'reviewed_by' => User::factory()->create(['role' => 'county'])->id,
            'status' => 'approved',
            'summary' => '其他审核员已完成的进展',
        ]);
        $permissionCatalog = collect(\App\Support\Role::permissionsCatalog());
        $permissionIds = $permissionCatalog->map(fn (array $item) => \App\Models\RbacPermission::query()->firstOrCreate(
            ['code' => $item['code']],
            ['name' => $item['name'], 'group' => $item['group']]
        )->id)->all();
        $role = \App\Models\RbacRole::query()->firstOrCreate(
            ['code' => 'county'],
            ['name' => '区县审核', 'is_builtin' => true, 'is_active' => true]
        );
        $role->permissions()->sync($permissionIds);

        Sanctum::actingAs($reviewer);

        $this->getJson('/api/lifecycle/progress')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/lifecycle/progress/{$record->id}/review", [
            'decision' => 'approve',
        ])->assertForbidden();
    }
}
