<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\ProjectFile;
use App\Models\ProjectReview;
use App\Models\DictionaryItem;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectApplicationWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_user_can_create_submit_and_withdraw_project(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $activeCountyReviewer = User::factory()->create(['role' => 'county', 'is_active' => true]);
        $inactiveCountyReviewer = User::factory()->create(['role' => 'county', 'is_active' => false]);

        Sanctum::actingAs($user);

        $createResponse = $this->postJson('/api/projects', [
            'title' => '智能制造专项申报',
            'category' => '科技项目',
            'project_type' => '重点扶持',
            'summary' => '用于验证申报端核心流程。',
            'budget_amount' => 123456.78,
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('title', '智能制造专项申报')
            ->assertJsonPath('status', Project::STATUS_DRAFT)
            ->assertJsonPath('unit_id', $unit->id)
            ->assertJsonPath('owner_id', $user->id);

        $projectId = $createResponse->json('id');

        $submitResponse = $this->postJson("/api/projects/{$projectId}/submit");
        $submitResponse->assertOk()
            ->assertJsonPath('status', Project::STATUS_SUBMITTED)
            ->assertJsonPath('current_reviewer_role', 'county');

        $this->assertDatabaseHas('messages', [
            'recipient_id' => $user->id,
            'project_id' => $projectId,
            'title' => '项目已提交',
        ]);
        $this->assertDatabaseHas('messages', [
            'recipient_id' => $activeCountyReviewer->id,
            'project_id' => $projectId,
            'title' => '收到待审项目',
        ]);
        $this->assertDatabaseMissing('messages', [
            'recipient_id' => $inactiveCountyReviewer->id,
            'project_id' => $projectId,
            'title' => '收到待审项目',
        ]);
        $this->assertDatabaseHas('operation_logs', ['action' => 'project.submitted']);

        $withdrawResponse = $this->postJson("/api/projects/{$projectId}/withdraw");
        $withdrawResponse->assertOk()
            ->assertJsonPath('status', Project::STATUS_DRAFT)
            ->assertJsonPath('current_reviewer_role', null);

        $this->assertDatabaseHas('operation_logs', ['action' => 'project.withdrawn']);
    }

    public function test_unit_user_cannot_access_another_units_project(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $otherOwner->id,
        ]);

        Sanctum::actingAs($user);

        $this->getJson("/api/projects/{$project->id}")->assertForbidden();
        $this->putJson("/api/projects/{$project->id}", [
            'title' => '越权修改',
        ])->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/submit")->assertForbidden();
    }

    public function test_unit_user_can_only_list_own_projects(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $ownProject = Project::factory()->create(['unit_id' => $ownUnit->id, 'owner_id' => $user->id]);
        Project::factory()->create(['unit_id' => $otherUnit->id, 'owner_id' => $otherOwner->id]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/projects');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($ownProject->id));
        $this->assertCount(1, $ids);
    }

    public function test_project_list_is_ordered_by_latest_business_time_descending(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $olderProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '较早创建项目',
            'status' => Project::STATUS_SUBMITTED,
            'submitted_at' => now()->subDays(2),
            'created_at' => now()->subDays(2),
        ]);
        $newerProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '较晚创建项目',
            'status' => Project::STATUS_SUBMITTED,
            'submitted_at' => now(),
            'created_at' => now(),
        ]);

        Sanctum::actingAs($admin);

        $ids = collect($this->getJson('/api/projects')->assertOk()->json('data'))->pluck('id')->all();

        $this->assertSame([$newerProject->id, $olderProject->id], array_slice($ids, 0, 2));
    }

    public function test_project_detail_includes_review_reviewer_profile(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $reviewer = User::factory()->create(['role' => 'county', 'username' => 'county-reviewer', 'name' => '区县审核员']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
        ]);
        $oldReview = ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $reviewer->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 80,
            'comment' => '旧审核时间',
            'reviewed_at' => now()->subDay(),
        ]);
        $newReview = ProjectReview::create([
            'project_id' => $project->id,
            'reviewer_id' => $reviewer->id,
            'stage' => 'county',
            'decision' => 'approve',
            'score' => 88,
            'comment' => '最新审核',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($owner);

        $this->getJson("/api/projects/{$project->id}")
            ->assertOk()
            ->assertJsonPath('reviews.0.id', $newReview->id)
            ->assertJsonPath('reviews.0.reviewer.username', 'county-reviewer')
            ->assertJsonPath('reviews.1.id', $oldReview->id)
            ->assertJsonPath('reviews.0.reviewer.name', '区县审核员');
    }

    public function test_expert_review_uses_configured_score_criteria(): void
    {
        DictionaryItem::query()
            ->where('group', 'expert_review_criterion')
            ->update(['is_active' => false]);

        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $expert = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'expert',
        ]);
        DictionaryItem::create([
            'group' => 'expert_review_criterion',
            'code' => 'policy_importance',
            'label' => '项目实施的重要性、必要性',
            'sort_order' => 10,
            'is_active' => true,
            'metadata' => ['section' => '政策符合性评价', 'max_score' => 40],
        ]);
        DictionaryItem::create([
            'group' => 'expert_review_criterion',
            'code' => 'technical_goals_clear',
            'label' => '研究目标是否明确清晰、重点突出',
            'sort_order' => 20,
            'is_active' => true,
            'metadata' => ['section' => '项目成果及技术水平评价', 'max_score' => 60],
        ]);

        Sanctum::actingAs($expert);

        $response = $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'recommend',
            'score' => 1,
            'comment' => '建议推荐',
            'metadata' => [
                'score_criteria' => [
                    'policy_importance' => 35,
                    'technical_goals_clear' => 50,
                ],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('review.score', '85.00')
            ->assertJsonPath('project.current_reviewer_role', 'admin');

        $review = ProjectReview::query()->firstOrFail();
        $this->assertSame('85.00', $review->score);
        $this->assertEquals(85.0, $review->metadata['score_total']);
        $this->assertEquals(100.0, $review->metadata['score_max']);
        $this->assertCount(2, $review->metadata['score_criteria']);
    }

    public function test_expert_review_requires_configured_score_criteria_for_recommendation(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $expert = User::factory()->create(['role' => 'expert']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'expert',
        ]);
        DictionaryItem::create([
            'group' => 'expert_review_criterion',
            'code' => 'budget_reasonable',
            'label' => '项目预算的合理性',
            'sort_order' => 10,
            'is_active' => true,
            'metadata' => ['section' => '经费预算', 'max_score' => 100],
        ]);

        Sanctum::actingAs($expert);

        $this->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'recommend',
            'comment' => '缺少评分',
            'metadata' => ['score_criteria' => []],
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('metadata.score_criteria');
    }

    public function test_project_cannot_be_updated_after_submission(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_SUBMITTED,
        ]);

        Sanctum::actingAs($user);

        $this->putJson("/api/projects/{$project->id}", [
            'title' => '提交后修改',
        ])->assertUnprocessable();
    }

    public function test_inactive_unit_cannot_write_project_or_upload_files(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create(['status' => 'inactive']);
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_DRAFT,
        ]);

        Sanctum::actingAs($user);

        $this->getJson('/api/projects')->assertOk();
        $this->getJson("/api/projects/{$project->id}")->assertOk();
        $this->postJson('/api/projects', [
            'title' => '停用单位新项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
        ])->assertForbidden();
        $this->putJson("/api/projects/{$project->id}", [
            'title' => '停用单位修改项目',
            'category' => $project->category,
            'project_type' => $project->project_type,
        ])->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/submit")->assertForbidden();
        $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('budget.pdf', 32, 'application/pdf'),
        ])->assertForbidden();
    }

    public function test_unit_user_can_upload_and_download_allowed_project_file(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);

        Sanctum::actingAs($user);

        $uploadResponse = $this->postJson("/api/projects/{$project->id}/files", [
            'file' => UploadedFile::fake()->create('budget.pdf', 32, 'application/pdf'),
            'purpose' => 'budget',
        ]);

        $uploadResponse->assertCreated()
            ->assertJsonPath('project_id', $project->id)
            ->assertJsonPath('uploaded_by', $user->id)
            ->assertJsonPath('original_name', 'budget.pdf')
            ->assertJsonPath('extension', 'pdf')
            ->assertJsonPath('purpose', 'budget');

        $file = ProjectFile::query()->firstOrFail();
        Storage::disk('local')->assertExists($file->path);

        $this->get("/api/files/{$file->id}/download")->assertOk();
        $this->assertDatabaseHas('operation_logs', ['action' => 'project_file.downloaded']);
    }

    public function test_unit_user_cannot_download_another_units_project_file(): void
    {
        Storage::fake('local');

        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $otherUnit->id, 'owner_id' => $otherOwner->id]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $otherOwner->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/secret.pdf',
            'original_name' => 'secret.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'secret'),
            'purpose' => 'application',
        ]);
        Storage::disk('local')->put($file->path, 'secret');

        Sanctum::actingAs($user);

        $this->get("/api/files/{$file->id}/download")->assertForbidden();
    }

    public function test_missing_project_file_download_returns_not_found_with_audit_log(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/missing.pdf',
            'original_name' => 'missing.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'missing'),
            'purpose' => 'application',
        ]);

        Sanctum::actingAs($user);

        $this->getJson("/api/files/{$file->id}/download")
            ->assertNotFound()
            ->assertJsonPath('message', '附件文件不存在');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.missing',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
        $this->assertDatabaseMissing('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.downloaded',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
    }

    public function test_invalid_project_file_path_is_rejected_with_audit_log(): void
    {
        Storage::fake('local');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);
        $file = ProjectFile::create([
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

        Sanctum::actingAs($user);

        $this->getJson("/api/files/{$file->id}/download")
            ->assertNotFound()
            ->assertJsonPath('message', '附件文件路径无效');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.invalid_path',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
        $this->assertDatabaseMissing('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.downloaded',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
    }

    public function test_invalid_project_file_disk_is_rejected_with_audit_log(): void
    {
        Storage::fake('public');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);
        $file = ProjectFile::create([
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
        Storage::disk('public')->put($file->path, 'public');

        Sanctum::actingAs($user);

        $this->getJson("/api/files/{$file->id}/download")
            ->assertNotFound()
            ->assertJsonPath('message', '附件存储磁盘无效');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.invalid_disk',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
        $this->assertDatabaseMissing('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.downloaded',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
    }

    public function test_legacy_project_file_path_can_be_downloaded(): void
    {
        Storage::fake('private');

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $user->id]);
        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $user->id,
            'disk' => 'private',
            'path' => 'legacy/projects/'.$project->id.'/pro_pro-'.$project->id.'-file0.pdf',
            'original_name' => 'legacy.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'legacy'),
            'purpose' => 'legacy_project_attachment',
        ]);
        Storage::disk('private')->put($file->path, 'legacy');

        Sanctum::actingAs($user);

        $this->get("/api/files/{$file->id}/download")->assertOk();
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project_file.downloaded',
            'target_type' => ProjectFile::class,
            'target_id' => $file->id,
        ]);
    }

    public function test_project_detail_returns_files_newest_first(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $project = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'status' => Project::STATUS_REVIEWING,
        ]);

        $oldFile = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $owner->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/old.pdf',
            'original_name' => 'old.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 100,
            'sha256' => hash('sha256', 'old'),
        ]);
        $newFile = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $owner->id,
            'disk' => 'local',
            'path' => 'project-files/'.$project->id.'/new.pdf',
            'original_name' => 'new.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 200,
            'sha256' => hash('sha256', 'new'),
        ]);
        $oldFile->forceFill(['created_at' => now()->subDay(), 'updated_at' => now()->subDay()])->save();
        $newFile->forceFill(['created_at' => now(), 'updated_at' => now()])->save();

        Sanctum::actingAs($owner);

        $this->getJson("/api/projects/{$project->id}")
            ->assertOk()
            ->assertJsonPath('files.0.id', $newFile->id)
            ->assertJsonPath('files.1.id', $oldFile->id);
    }
}
