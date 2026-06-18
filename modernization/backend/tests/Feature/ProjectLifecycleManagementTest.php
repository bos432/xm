<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectFile;
use App\Models\OperationLog;
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
}
