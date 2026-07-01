<?php

namespace Tests\Feature;

use App\Models\ApplicationBatch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApplicationBatchManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_filter_e2e_application_batches(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);

        ApplicationBatch::create([
            'name' => 'E2E 测试批次',
            'code' => 'E2E-FILTER',
            'status' => ApplicationBatch::STATUS_OPEN,
            'metadata' => ['e2e' => true],
        ]);
        ApplicationBatch::create([
            'name' => '正式批次',
            'code' => 'BUSINESS-FILTER',
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);

        $e2e = collect($this->getJson('/api/application-batches?e2e=1')->assertOk()->json('data'));
        $business = collect($this->getJson('/api/application-batches?e2e=0')->assertOk()->json('data'));

        $this->assertTrue($e2e->pluck('code')->contains('E2E-FILTER'));
        $this->assertFalse($e2e->pluck('code')->contains('BUSINESS-FILTER'));
        $this->assertTrue($business->pluck('code')->contains('BUSINESS-FILTER'));
        $this->assertFalse($business->pluck('code')->contains('E2E-FILTER'));
    }

    public function test_only_super_admin_can_bulk_archive_e2e_application_batches(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $superAdmin = User::factory()->create(['role' => 'super_admin']);

        $e2e = ApplicationBatch::create([
            'name' => 'E2E 归档批次',
            'code' => 'E2E-ARCHIVE',
            'status' => ApplicationBatch::STATUS_OPEN,
            'metadata' => ['e2e' => true],
        ]);
        $business = ApplicationBatch::create([
            'name' => '正式归档保护批次',
            'code' => 'BUSINESS-ARCHIVE',
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);

        Sanctum::actingAs($admin);
        $this->postJson('/api/application-batches/archive-e2e')->assertForbidden();

        Sanctum::actingAs($superAdmin);
        $this->postJson('/api/application-batches/archive-e2e')
            ->assertOk()
            ->assertJsonPath('archived_count', 1)
            ->assertJsonPath('batch_ids.0', $e2e->id);

        $this->assertSame(ApplicationBatch::STATUS_ARCHIVED, $e2e->refresh()->status);
        $this->assertSame(ApplicationBatch::STATUS_OPEN, $business->refresh()->status);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $superAdmin->id,
            'action' => 'application_batch.e2e_archived',
        ]);
    }
}
