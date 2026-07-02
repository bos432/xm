<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProjectExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_user_exports_only_own_projects_with_status_filter(): void
    {
        $ownUnit = Unit::factory()->create();
        $otherUnit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $ownUnit->id, 'role' => 'unit']);
        $otherOwner = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $ownDraft = Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $user->id,
            'title' => '本单位草稿项目',
            'status' => Project::STATUS_DRAFT,
        ]);
        Project::factory()->create([
            'unit_id' => $ownUnit->id,
            'owner_id' => $user->id,
            'title' => '本单位已提交项目',
            'status' => Project::STATUS_SUBMITTED,
        ]);
        Project::factory()->create([
            'unit_id' => $otherUnit->id,
            'owner_id' => $otherOwner->id,
            'title' => '其他单位草稿项目',
            'status' => Project::STATUS_DRAFT,
        ]);

        Sanctum::actingAs($user);

        $response = $this->get('/api/projects/export.csv?status=draft');

        $response->assertOk();
        $csv = $response->streamedContent();
        $this->assertStringContainsString('项目ID', $csv);
        $this->assertStringContainsString($ownDraft->title, $csv);
        $this->assertStringNotContainsString('本单位已提交项目', $csv);
        $this->assertStringNotContainsString('其他单位草稿项目', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'project.exported',
        ]);
    }

    public function test_project_export_can_be_filtered_by_keyword(): void
    {
        $unit = Unit::factory()->create(['name' => '东城创新单位']);
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $matched = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'title' => '智能制造导出项目',
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'title' => '普通服务导出项目',
        ]);

        Sanctum::actingAs($user);

        $csv = $this->get('/api/projects/export.csv?keyword=' . urlencode('智能制造'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString($matched->title, $csv);
        $this->assertStringNotContainsString('普通服务导出项目', $csv);
    }

    public function test_project_export_can_be_filtered_by_category_and_type(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $matched = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'title' => '科技重点导出项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $user->id,
            'title' => '产业示范导出项目',
            'category' => '产业项目',
            'project_type' => '创新示范',
        ]);

        Sanctum::actingAs($user);

        $csv = $this->get('/api/projects/export.csv?category=' . urlencode('科技项目') . '&project_type=' . urlencode('重点扶持'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString($matched->title, $csv);
        $this->assertStringNotContainsString('产业示范导出项目', $csv);
    }

    public function test_admin_export_can_include_projects_across_units(): void
    {
        $firstUnit = Unit::factory()->create();
        $secondUnit = Unit::factory()->create();
        $firstOwner = User::factory()->create(['unit_id' => $firstUnit->id, 'role' => 'unit']);
        $secondOwner = User::factory()->create(['unit_id' => $secondUnit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        Project::factory()->create([
            'unit_id' => $firstUnit->id,
            'owner_id' => $firstOwner->id,
            'title' => '第一单位项目',
        ]);
        Project::factory()->create([
            'unit_id' => $secondUnit->id,
            'owner_id' => $secondOwner->id,
            'title' => '第二单位项目',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->get('/api/projects/export.csv');

        $response->assertOk();
        $csv = $response->streamedContent();
        $this->assertStringContainsString('第一单位项目', $csv);
        $this->assertStringContainsString('第二单位项目', $csv);
    }

    public function test_project_export_can_be_filtered_by_pending_extension_requests(): void
    {
        $unit = Unit::factory()->create();
        $owner = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $admin = User::factory()->create(['role' => 'admin']);
        $pendingProject = Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '待导出延期项目',
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '待处理延期',
                    'status' => 'pending',
                ]],
            ],
        ]);
        Project::factory()->create([
            'unit_id' => $unit->id,
            'owner_id' => $owner->id,
            'title' => '已处理延期导出项目',
            'status' => Project::STATUS_ACCEPTANCE,
            'metadata' => [
                'extension_requests' => [[
                    'reason' => '已处理延期',
                    'status' => 'rejected',
                ]],
            ],
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/projects/export.csv?pending_extension=1')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('待处理延期', $csv);
        $this->assertStringContainsString($pendingProject->title, $csv);
        $this->assertStringNotContainsString('已处理延期导出项目', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'project.exported',
        ]);
    }
}
