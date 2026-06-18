<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UnitManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_and_update_unit_with_audit_logs(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        Sanctum::actingAs($admin);

        $createResponse = $this->postJson('/api/units', [
            'name' => '杭州智能制造有限公司',
            'credit_code' => '91330100MA000001',
            'contact_name' => '张三',
            'contact_mobile' => '13800000000',
            'email' => 'contact@example.test',
            'address' => '杭州市测试路 1 号',
            'region_code' => '330100',
            'status' => 'active',
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('name', '杭州智能制造有限公司')
            ->assertJsonPath('status', 'active');
        $unitId = $createResponse->json('id');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'unit.created',
            'target_type' => Unit::class,
            'target_id' => $unitId,
        ]);

        $this->putJson("/api/units/{$unitId}", [
            'name' => '杭州智能制造有限公司',
            'credit_code' => '91330100MA000001',
            'contact_name' => '李四',
            'contact_mobile' => '13900000000',
            'email' => 'contact@example.test',
            'address' => '杭州市测试路 2 号',
            'region_code' => '330100',
            'status' => 'suspended',
        ])->assertOk()
            ->assertJsonPath('contact_name', '李四')
            ->assertJsonPath('status', 'suspended');

        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'unit.updated',
            'target_type' => Unit::class,
            'target_id' => $unitId,
        ]);
    }

    public function test_unit_user_can_view_only_own_unit_profile(): void
    {
        $unit = Unit::factory()->create(['name' => '本单位']);
        $user = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);

        Sanctum::actingAs($user);

        $this->getJson('/api/units/me')->assertOk()
            ->assertJsonPath('id', $unit->id)
            ->assertJsonPath('name', '本单位');
        $this->getJson('/api/units')->assertForbidden();
        $this->postJson('/api/units', [
            'name' => '越权新增单位',
            'status' => 'active',
        ])->assertForbidden();
    }

    public function test_reviewer_cannot_manage_units_or_view_unit_profile(): void
    {
        $reviewer = User::factory()->create(['role' => 'county']);
        $unit = Unit::factory()->create();

        Sanctum::actingAs($reviewer);

        $this->getJson('/api/units')->assertForbidden();
        $this->getJson('/api/units/me')->assertForbidden();
        $this->putJson("/api/units/{$unit->id}", [
            'name' => '越权修改',
            'status' => 'active',
        ])->assertForbidden();
    }

    public function test_admin_can_filter_units_by_keyword(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Unit::factory()->create(['name' => '浙江云平台公司', 'credit_code' => 'AAA001']);
        Unit::factory()->create(['name' => '杭州制造公司', 'credit_code' => 'BBB002']);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/units?keyword=云平台')->assertOk();
        $names = collect($response->json('data'))->pluck('name');
        $this->assertTrue($names->contains('浙江云平台公司'));
        $this->assertFalse($names->contains('杭州制造公司'));
    }

    public function test_deactivating_unit_revokes_tokens_for_unit_users_only(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $unit = Unit::factory()->create(['status' => 'active']);
        $otherUnit = Unit::factory()->create(['status' => 'active']);
        $firstUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $secondUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $otherUser = User::factory()->create(['unit_id' => $otherUnit->id, 'role' => 'unit']);
        $firstUser->createToken('web');
        $secondUser->createToken('web');
        $secondUser->createToken('mobile');
        $otherUser->createToken('web');

        Sanctum::actingAs($admin);

        $this->putJson("/api/units/{$unit->id}", [
            'name' => $unit->name,
            'credit_code' => $unit->credit_code,
            'contact_name' => $unit->contact_name,
            'contact_mobile' => $unit->contact_mobile,
            'email' => $unit->email,
            'address' => $unit->address,
            'region_code' => $unit->region_code,
            'status' => 'suspended',
        ])->assertOk()
            ->assertJsonPath('status', 'suspended');

        $this->assertSame(0, $firstUser->tokens()->count());
        $this->assertSame(0, $secondUser->tokens()->count());
        $this->assertSame(1, $otherUser->tokens()->count());
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'unit.tokens_revoked',
            'target_type' => Unit::class,
            'target_id' => $unit->id,
        ]);
    }
}
