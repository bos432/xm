<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\DictionaryItem;
use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AuthenticatedProjectLifecycleE2eTest extends TestCase
{
    use RefreshDatabase;

    public function withToken(string $token, string $type = 'Bearer')
    {
        $this->app['auth']->forgetGuards();

        return parent::withToken($token, $type);
    }

    public function test_six_authenticated_roles_can_submit_review_score_and_close_acceptance(): void
    {
        $expectedDriver = getenv('QA_EXPECTED_DB_DRIVER');
        if ($expectedDriver !== false) {
            $this->assertSame($expectedDriver, DB::connection()->getDriverName());
        }
        Storage::fake('local');
        config(['filesystems.default' => 'local']);

        $unit = Unit::factory()->create(['status' => 'active']);
        $unitUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit', 'username' => 'qa_unit', 'metadata' => ['e2e' => true]]);
        $county = User::factory()->create(['role' => 'county', 'username' => 'qa_county']);
        $department = User::factory()->create(['role' => 'department', 'username' => 'qa_department']);
        $experts = User::factory()->count(3)->sequence(
            ['username' => 'qa_expert_1'], ['username' => 'qa_expert_2'], ['username' => 'qa_expert_3']
        )->create(['role' => 'expert']);
        $admin = User::factory()->create(['role' => 'admin', 'username' => 'qa_admin']);
        $superAdmin = User::factory()->create(['role' => 'super_admin', 'username' => 'qa_super_admin']);
        $batch = ApplicationBatch::create([
            'name' => 'E2E-QA-ISOLATED-BATCH',
            'code' => 'E2E-QA-ISOLATED',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
            'metadata' => ['acceptance_required_materials' => ['acceptance_application', 'financial']],
        ]);
        foreach ([['quality', 'Quality', 35], ['innovation', 'Innovation', 35], ['impact', 'Impact', 30]] as [$code, $label, $score]) {
            DictionaryItem::create([
                'group' => 'expert_review_criterion', 'code' => $code, 'label' => $label,
                'sort_order' => $score, 'is_active' => true, 'metadata' => ['max_score' => $score],
            ]);
        }

        $tokens = [];
        foreach ([$unitUser, $county, $department, ...$experts, $admin, $superAdmin] as $user) {
            $captcha = $this->getJson('/api/auth/captcha')->assertOk()->json();
            preg_match_all('/\d+/', $captcha['question'], $numbers);
            $response = $this->postJson('/api/auth/login', [
                'username' => $user->username,
                'password' => 'password',
                'captcha_id' => $captcha['captcha_id'],
                'captcha_answer' => array_sum(array_map('intval', $numbers[0])),
            ])->assertOk();
            $tokens[$user->id] = $response->json('token');
            $this->withToken($tokens[$user->id])->getJson('/api/auth/me')->assertOk()
                ->assertJsonPath('id', $user->id)->assertJsonPath('role', $user->role);
        }
        $this->assertCount(8, $tokens);
        $this->withToken($tokens[$superAdmin->id])->getJson('/api/auth/me')->assertOk()
            ->assertJsonPath('role', 'super_admin');

        $this->withToken($tokens[$unitUser->id])->postJson('/api/projects', [
            'title' => 'E2E-QA-ISOLATED-PROJECT',
            'application_batch_id' => $batch->id,
            'category' => 'QA Category',
            'project_type' => 'QA Type',
            'summary' => '隔离环境全流程端到端验证',
            'budget_amount' => 125000,
        ])->assertCreated()->assertJsonPath('status', Project::STATUS_DRAFT);
        $project = Project::query()->where('title', 'E2E-QA-ISOLATED-PROJECT')->firstOrFail();
        $this->withToken($tokens[$unitUser->id])->postJson("/api/projects/{$project->id}/submit")
            ->assertOk()->assertJsonPath('current_reviewer_role', 'county');

        $this->withToken($tokens[$county->id])->getJson('/api/reviews/tasks')
            ->assertOk()->assertJsonPath('data.0.id', $project->id);
        $this->withToken($tokens[$county->id])->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'return', 'comment' => 'Please clarify the research plan',
        ])->assertCreated()->assertJsonPath('project.status', Project::STATUS_RETURNED);
        $this->withToken($tokens[$unitUser->id])->putJson("/api/projects/{$project->id}", [
            'title' => $project->title, 'summary' => 'Revised research plan after county feedback',
        ])->assertOk();
        $this->withToken($tokens[$unitUser->id])->postJson("/api/projects/{$project->id}/submit")
            ->assertOk()->assertJsonPath('current_reviewer_role', 'county');
        $this->withToken($tokens[$county->id])->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'approve'])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'department');
        $this->withToken($tokens[$department->id])->postJson("/api/projects/{$project->id}/reviews", ['decision' => 'approve'])
            ->assertCreated()->assertJsonPath('project.current_reviewer_role', 'expert');

        $expertIds = array_map('intval', data_get($project->fresh()->metadata, 'review_dispatch.assignments.expert.assigned_user_ids', []));
        $this->assertCount(3, $expertIds);
        foreach ($expertIds as $index => $expertId) {
            $expert = $experts->firstWhere('id', $expertId);
            $this->assertNotNull($expert);
            $this->withToken($tokens[$expertId])->getJson('/api/reviews/tasks')
                ->assertOk()->assertJsonPath('data.0.id', $project->id);
            $this->withToken($tokens[$expertId])->postJson("/api/projects/{$project->id}/reviews", [
                'decision' => 'recommend',
                'metadata' => ['score_criteria' => ['quality' => 30 + $index, 'innovation' => 30, 'impact' => 25]],
            ])->assertCreated();
            $this->withToken($tokens[$expertId])->getJson('/api/reviews/tasks')
                ->assertOk()->assertJsonCount(0, 'data');
        }
        $this->assertSame('admin', $project->fresh()->current_reviewer_role);
        $this->assertSame(3, ProjectReview::query()->where('project_id', $project->id)->where('stage', 'expert')->count());
        $this->withToken($tokens[$admin->id])->postJson("/api/projects/{$project->id}/reviews", [
            'decision' => 'accept', 'comment' => '隔离 E2E 终审通过',
            'metadata' => ['final_support' => ['is_supported' => true, 'subsidy_amount_wan' => 10]],
        ])->assertCreated()->assertJsonPath('project.status', Project::STATUS_APPROVED);

        $this->withToken($tokens[$unitUser->id])->postJson("/api/projects/{$project->id}/acceptance", [
            'summary' => 'E2E验收材料已准备',
        ])->assertCreated();
        $acceptance = $project->acceptanceApplications()->firstOrFail();
        $this->withToken($tokens[$unitUser->id])->postJson("/api/acceptance/{$acceptance->id}/submit")
            ->assertUnprocessable()->assertJsonCount(2, 'missing_materials');
        $extension = $this->withToken($tokens[$unitUser->id])->postJson("/api/acceptance/{$acceptance->id}/extensions", [
            'reason' => 'Independent laboratory report delayed', 'expected_date' => now()->addMonth()->toDateString(),
        ])->assertCreated()->assertJsonPath('status', 'pending')->json();
        $this->withToken($tokens[$admin->id])->getJson('/api/acceptance?scope=visible')
            ->assertOk()->assertJsonPath('data.0.pending_extension_count', 1);
        $this->withToken($tokens[$county->id])->postJson("/api/acceptance/{$acceptance->id}/extensions", [
            'extension_id' => $extension['id'], 'decision' => 'approved',
        ])->assertForbidden();
        $this->withToken($tokens[$admin->id])->postJson("/api/acceptance/{$acceptance->id}/extensions", [
            'extension_id' => $extension['id'], 'decision' => 'approved', 'comment' => 'Approved after checking report schedule',
        ])->assertOk()->assertJsonPath('status', 'approved');
        $this->withToken($tokens[$unitUser->id])->getJson("/api/acceptance/{$acceptance->id}")
            ->assertOk()->assertJsonPath('extensions.0.status', 'approved');
        foreach (['acceptance_application', 'project_summary', 'financial', 'achievement', 'other'] as $category) {
            $this->withToken($tokens[$unitUser->id])->postJson("/api/acceptance/{$acceptance->id}/files", [
                'file' => UploadedFile::fake()->create($category.'.pdf', 10, 'application/pdf'),
                'metadata' => ['material_category' => $category],
            ])->assertCreated();
        }
        $this->withToken($tokens[$unitUser->id])->postJson("/api/acceptance/{$acceptance->id}/submit", [
            'summary' => '全部验收附件已上传',
        ])->assertOk()->assertJsonPath('current_reviewer_role', 'county');

        foreach ([[$county, 'county'], [$department, 'department'], [$experts->firstWhere('id', $expertIds[0]), 'expert'], [$admin, 'admin']] as [$reviewer, $stage]) {
            $this->withToken($tokens[$reviewer->id])->getJson('/api/acceptance?scope=pending')
                ->assertOk()->assertJsonPath('data.0.current_reviewer_role', $stage);
            $this->withToken($tokens[$reviewer->id])->postJson("/api/acceptance/{$acceptance->id}/reviews", [
                'decision' => $stage === 'admin' ? 'close' : 'approve', 'comment' => 'E2E验收审核通过',
            ])->assertCreated();
        }
        $this->assertSame('closed', $acceptance->fresh()->status);
        $this->assertSame(Project::STATUS_CLOSED, $project->fresh()->status);
        $this->withToken($tokens[$unitUser->id])->getJson("/api/acceptance/{$acceptance->id}")->assertOk();
        $this->withToken($tokens[$unitUser->id])->getJson('/api/settings/groups')->assertForbidden();
        foreach ($tokens as $token) {
            $this->withToken($token)->postJson('/api/auth/logout')->assertNoContent();
            $this->withToken($token)->getJson('/api/auth/me')->assertUnauthorized();
        }
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
