<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UploadSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_dangerous_upload_extensions_are_rejected(): void
    {
        [$project] = $this->actingAsUnitProjectApplicant();

        foreach (['php', 'jsp', 'asp', 'phtml', 'phar'] as $extension) {
            $response = $this->postJson("/api/projects/{$project->id}/files", [
                'file' => UploadedFile::fake()->create("shell.{$extension}", 10, 'application/octet-stream'),
            ]);

            $response->assertUnprocessable();
        }
    }

    public function test_disguised_executable_uploads_are_rejected(): void
    {
        [$project] = $this->actingAsUnitProjectApplicant();

        $response = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('invoice.php.jpg', 10, 'image/jpeg'),
        ]);

        $response->assertUnprocessable();
    }

    public function test_path_traversal_file_names_are_rejected(): void
    {
        [$project] = $this->actingAsUnitProjectApplicant();

        $response = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('budget..pdf', 10, 'application/pdf'),
        ]);

        $response->assertUnprocessable();
    }

    public function test_oversized_uploads_are_rejected(): void
    {
        Config::set('modernization.upload_max_kb', 8);
        [$project] = $this->actingAsUnitProjectApplicant();

        $response = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('large.pdf', 16, 'application/pdf'),
        ]);

        $response->assertUnprocessable();
    }

    public function test_allowed_upload_is_still_accepted(): void
    {
        [$project] = $this->actingAsUnitProjectApplicant();

        $response = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('budget.pdf', 4, 'application/pdf'),
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('project_files', [
            'project_id' => $project->id,
            'original_name' => 'budget.pdf',
            'extension' => 'pdf',
        ]);
    }

    public function test_uploaded_original_file_name_is_sanitized(): void
    {
        [$project] = $this->actingAsUnitProjectApplicant();

        $response = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create("budget\r\nreport.pdf", 4, 'application/pdf'),
        ]);

        $response->assertCreated()
            ->assertJsonPath('original_name', 'budget report.pdf');

        $this->assertDatabaseHas('project_files', [
            'project_id' => $project->id,
            'original_name' => 'budget report.pdf',
        ]);
    }

    public function test_rich_text_image_upload_requires_a_role_that_can_edit_rich_text(): void
    {
        Storage::fake('local');
        $county = User::factory()->create(['role' => 'county']);
        Sanctum::actingAs($county);

        $this->postJson('/api/rich-text-images', [
            'file' => UploadedFile::fake()->image('image.png'),
        ])->assertForbidden();

        $unit = Unit::factory()->create();
        $applicant = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        Sanctum::actingAs($applicant);
        $response = $this->postJson('/api/rich-text-images', [
            'file' => UploadedFile::fake()->image('image.png'),
        ])->assertOk();

        Storage::disk('local')->assertExists($response->json('path'));
    }

    public function test_admin_can_upload_rich_text_image_for_public_home_content(): void
    {
        Storage::fake('local');
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));

        $response = $this->postJson('/api/rich-text-images', [
            'file' => UploadedFile::fake()->image('notice.png'),
        ])->assertOk();

        Storage::disk('local')->assertExists($response->json('path'));
    }

    private function actingAsUnitProjectApplicant(): array
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);

        Sanctum::actingAs($user);

        return [$project, $user, $unit];
    }
}
