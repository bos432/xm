<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_and_update_user_with_audit_logs(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $unit = Unit::factory()->create();

        Sanctum::actingAs($admin);

        $createResponse = $this->postJson('/api/users', [
            'name' => '申报员',
            'username' => 'unit-applicant',
            'email' => 'unit-applicant@example.test',
            'mobile' => '13800000001',
            'password' => 'secret-password',
            'role' => 'unit',
            'unit_id' => $unit->id,
            'is_active' => true,
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('username', 'unit-applicant')
            ->assertJsonPath('unit_id', $unit->id)
            ->assertJsonMissing(['password' => 'secret-password']);
        $userId = $createResponse->json('id');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.created',
            'target_type' => User::class,
            'target_id' => $userId,
        ]);

        $this->putJson("/api/users/{$userId}", [
            'name' => '区县审核员',
            'username' => 'unit-applicant',
            'email' => 'county-reviewer@example.test',
            'mobile' => '13800000002',
            'role' => 'county',
            'unit_id' => null,
            'is_active' => false,
        ])->assertOk()
            ->assertJsonPath('name', '区县审核员')
            ->assertJsonPath('role', 'county')
            ->assertJsonPath('is_active', false);

        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.updated',
            'target_type' => User::class,
            'target_id' => $userId,
        ]);
    }

    public function test_non_admin_cannot_manage_users(): void
    {
        $unit = Unit::factory()->create();
        $unitUser = User::factory()->create(['unit_id' => $unit->id, 'role' => 'unit']);
        $target = User::factory()->create(['role' => 'expert']);

        Sanctum::actingAs($unitUser);

        $this->getJson('/api/users')->assertForbidden();
        $this->postJson('/api/users', [
            'name' => '越权账号',
            'username' => 'forbidden-user',
            'password' => 'secret-password',
            'role' => 'unit',
            'is_active' => true,
        ])->assertForbidden();
        $this->putJson("/api/users/{$target->id}", [
            'name' => '越权修改',
            'username' => $target->username,
            'role' => 'expert',
            'is_active' => true,
        ])->assertForbidden();
    }

    public function test_inactive_user_cannot_login(): void
    {
        $user = User::factory()->create([
            'username' => 'inactive-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
            'is_active' => false,
        ]);

        $this->postJson('/api/auth/login', [
            'username' => 'inactive-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertUnprocessable();

        $this->assertDatabaseHas('operation_logs', [
            'action' => 'auth.login_failed',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
    }

    public function test_admin_profile_contains_user_management_menu(): void
    {
        User::factory()->create([
            'username' => 'admin-user',
            'password' => Hash::make('secret-password'),
            'role' => 'admin',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'username' => 'admin-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertOk();

        $permissions = collect($response->json('user.permissions'));
        $menus = collect($response->json('user.menus'))->pluck('path');
        $this->assertTrue($permissions->contains('manage_users'));
        $this->assertTrue($menus->contains('/users'));
    }

    public function test_admin_can_filter_users_by_active_status(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $active = User::factory()->create(['username' => 'active-user', 'is_active' => true]);
        User::factory()->create(['username' => 'inactive-user', 'is_active' => false]);

        Sanctum::actingAs($admin);

        $ids = collect($this->getJson('/api/users?is_active=1')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($active->id));
        $this->assertFalse($ids->contains($admin->id));
        $this->assertCount(1, $ids);
    }

    public function test_deactivating_user_revokes_existing_tokens(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $user = User::factory()->create([
            'username' => 'token-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
            'is_active' => true,
        ]);
        $user->createToken('web');
        $user->createToken('mobile');

        Sanctum::actingAs($admin);

        $this->putJson("/api/users/{$user->id}", [
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'mobile' => $user->mobile,
            'role' => $user->role,
            'unit_id' => $user->unit_id,
            'is_active' => false,
        ])->assertOk()
            ->assertJsonPath('is_active', false);

        $this->assertSame(0, $user->tokens()->count());
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.tokens_revoked',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
    }

    public function test_super_admin_password_reset_revokes_existing_tokens(): void
    {
        $admin = User::factory()->create(['role' => 'super_admin']);
        $user = User::factory()->create([
            'username' => 'reset-user',
            'password' => Hash::make('old-password'),
            'role' => 'unit',
            'is_active' => true,
        ]);
        $user->createToken('web');

        Sanctum::actingAs($admin);

        $this->putJson("/api/users/{$user->id}/password", [
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertOk();

        $this->assertSame(0, $user->tokens()->count());
        $this->assertTrue(Hash::check('new-password', $user->refresh()->password));
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.password_reset',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.tokens_revoked',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
    }

    public function test_business_admin_cannot_reset_user_password(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $user = User::factory()->create([
            'username' => 'business-reset-user',
            'password' => Hash::make('old-password'),
            'role' => 'unit',
        ]);

        Sanctum::actingAs($admin);

        $this->putJson("/api/users/{$user->id}/password", [
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertForbidden();

        $this->assertTrue(Hash::check('old-password', $user->refresh()->password));
    }

    public function test_inactive_user_token_is_rejected_by_active_middleware(): void
    {
        $user = User::factory()->create([
            'username' => 'inactive-token-user',
            'role' => 'unit',
            'is_active' => false,
        ]);

        Sanctum::actingAs($user);

        $this->getJson('/api/auth/me')->assertForbidden();
        $this->getJson('/api/dashboard/summary')->assertForbidden();
        $this->getJson('/api/projects')->assertForbidden();

        $this->assertSame(0, $user->tokens()->count(), '停用账号的登录 token 应被删除');
    }
}
