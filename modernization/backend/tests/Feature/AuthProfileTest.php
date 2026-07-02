<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use App\Models\SecurityLock;
use App\Support\RuntimeConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_returns_role_permissions_and_menus(): void
    {
        $unit = Unit::factory()->create();
        User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'unit-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'username' => 'unit-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'token',
                'user' => [
                    'id',
                    'username',
                    'role',
                    'last_login_at',
                    'last_login_ip',
                    'permissions',
                    'menus',
                    'unit',
                ],
            ])
            ->assertJsonPath('user.role', 'unit')
            ->assertJsonPath('user.last_login_ip', '127.0.0.1');

        $permissions = collect($response->json('user.permissions'));
        $menus = collect($response->json('user.menus'))->pluck('path');

        $this->assertTrue($permissions->contains('create_projects'));
        $this->assertTrue($permissions->contains('upload_project_files'));
        $this->assertTrue($menus->contains('/projects'));
        $this->assertFalse($menus->contains('/settings'));
        $this->assertFalse($menus->contains('/migration'));
        $this->assertDatabaseHas('users', [
            'username' => 'unit-user',
            'last_login_ip' => '127.0.0.1',
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'action' => 'auth.login',
            'target_type' => User::class,
        ]);
    }

    public function test_acceptance_reviewers_receive_acceptance_menu_entry(): void
    {
        User::factory()->create([
            'username' => 'county-user',
            'password' => Hash::make('secret-password'),
            'role' => 'county',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'username' => 'county-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ]);

        $response->assertOk();

        $menus = collect($response->json('user.menus'));
        $this->assertTrue($menus->contains(fn (array $menu) => $menu['path'] === '/acceptance?scope=pending'));
    }

    public function test_login_route_is_rate_limited(): void
    {
        RuntimeConfig::set('security.login_failure_threshold', '100', 'security', false, '登录失败锁定阈值');

        User::factory()->create([
            'username' => 'limited-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/auth/login', [
                'username' => 'limited-user',
                'password' => 'wrong-password',
                ...$this->validCaptchaPayload(),
            ])->assertUnprocessable();
        }

        $this->postJson('/api/auth/login', [
            'username' => 'limited-user',
            'password' => 'wrong-password',
            ...$this->validCaptchaPayload(),
        ])->assertTooManyRequests()
            ->assertJsonPath('message', '登录过于频繁，请稍后再试')
            ->assertJsonStructure(['retry_after_seconds']);

        $this->assertDatabaseHas('security_events', [
            'type' => 'auth.throttled',
            'username' => 'limited-user',
            'ip_address' => '127.0.0.1',
        ]);
    }

    public function test_login_throttle_can_be_relaxed_for_whitelisted_test_ip(): void
    {
        RuntimeConfig::set('security.login_failure_threshold', '100', 'security', false, '登录失败锁定阈值');
        RuntimeConfig::set('security.login_throttle_per_minute', '1', 'security', false, '登录接口每分钟限制');
        RuntimeConfig::set('security.login_throttle_whitelist_ips', '127.0.0.1', 'security', false, '登录限流测试白名单 IP');
        RuntimeConfig::set('security.login_throttle_relaxed_per_minute', '10', 'security', false, '临时放宽后的每分钟限制');

        User::factory()->create([
            'username' => 'whitelist-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);

        for ($attempt = 0; $attempt < 3; $attempt++) {
            $this->postJson('/api/auth/login', [
                'username' => 'whitelist-user',
                'password' => 'wrong-password',
                ...$this->validCaptchaPayload(),
            ])->assertUnprocessable();
        }
    }

    public function test_login_throttle_relaxed_mode_expires_automatically(): void
    {
        RuntimeConfig::set('security.login_failure_threshold', '100', 'security', false, '登录失败锁定阈值');
        RuntimeConfig::set('security.login_throttle_per_minute', '1', 'security', false, '登录接口每分钟限制');
        RuntimeConfig::set('security.login_throttle_relaxed', '1', 'security', false, '是否临时放宽登录限流');
        RuntimeConfig::set('security.login_throttle_relaxed_per_minute', '10', 'security', false, '临时放宽后的每分钟限制');
        RuntimeConfig::set('security.login_throttle_relaxed_until', now()->subMinute()->toDateTimeString(), 'security', false, '登录限流临时放宽截止时间');

        User::factory()->create([
            'username' => 'expired-relaxed-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);

        $this->postJson('/api/auth/login', [
            'username' => 'expired-relaxed-user',
            'password' => 'wrong-password',
            ...$this->validCaptchaPayload(),
        ])->assertUnprocessable();

        $this->postJson('/api/auth/login', [
            'username' => 'expired-relaxed-user',
            'password' => 'wrong-password',
            ...$this->validCaptchaPayload(),
        ])->assertTooManyRequests()
            ->assertJsonStructure(['retry_after_seconds']);
    }

    public function test_locked_login_response_includes_retry_after_seconds(): void
    {
        User::factory()->create([
            'username' => 'locked-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);
        SecurityLock::create([
            'identity_type' => 'username',
            'identity_value' => 'locked-user',
            'failed_count' => 5,
            'reason' => 'invalid_password',
            'is_active' => true,
            'locked_until' => now()->addMinutes(5),
        ]);

        $this->postJson('/api/auth/login', [
            'username' => 'locked-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertStatus(423)
            ->assertJsonPath('message', '登录失败次数过多，请稍后再试或联系管理员解锁')
            ->assertJsonStructure(['retry_after_seconds']);
    }

    public function test_captcha_can_be_generated_for_login(): void
    {
        $this->getJson('/api/auth/captcha')->assertOk()
            ->assertJsonStructure(['captcha_id', 'question']);
    }

    public function test_login_requires_valid_captcha(): void
    {
        User::factory()->create([
            'username' => 'captcha-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
        ]);

        $captcha = $this->validCaptchaPayload(9);

        $this->postJson('/api/auth/login', [
            'username' => 'captcha-user',
            'password' => 'secret-password',
            'captcha_id' => $captcha['captcha_id'],
            'captcha_answer' => 8,
        ])->assertUnprocessable()
            ->assertJsonPath('message', '验证码错误');

        $this->assertDatabaseMissing('operation_logs', [
            'action' => 'auth.login',
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'action' => 'auth.captcha_failed',
            'target_type' => null,
            'target_id' => null,
            'ip_address' => '127.0.0.1',
        ]);
    }

    public function test_failed_login_is_audited_without_updating_last_login(): void
    {
        $user = User::factory()->create([
            'username' => 'audited-user',
            'password' => Hash::make('secret-password'),
            'role' => 'unit',
            'last_login_at' => null,
            'last_login_ip' => null,
        ]);

        $this->postJson('/api/auth/login', [
            'username' => 'audited-user',
            'password' => 'wrong-password',
            ...$this->validCaptchaPayload(),
        ])->assertUnprocessable()
            ->assertJsonPath('message', '账号或密码错误');

        $this->assertNull($user->refresh()->last_login_at);
        $this->assertNull($user->last_login_ip);
        $this->assertDatabaseHas('operation_logs', [
            'action' => 'auth.login_failed',
            'target_type' => User::class,
            'target_id' => $user->id,
            'ip_address' => '127.0.0.1',
        ]);
    }

    public function test_unknown_account_login_is_audited_without_target_user(): void
    {
        $this->postJson('/api/auth/login', [
            'username' => 'missing-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertUnprocessable()
            ->assertJsonPath('message', '账号或密码错误');

        $this->assertDatabaseHas('operation_logs', [
            'action' => 'auth.login_failed',
            'target_type' => null,
            'target_id' => null,
            'ip_address' => '127.0.0.1',
        ]);
    }

    public function test_admin_profile_contains_logs_but_not_migration_or_sensitive_settings(): void
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
        ]);

        $response->assertOk();

        $permissions = collect($response->json('user.permissions'));
        $menus = collect($response->json('user.menus'))->pluck('path');

        $this->assertFalse($permissions->contains('view_migration'));
        $this->assertFalse($permissions->contains('manage_settings'));
        $this->assertTrue($permissions->contains('view_operation_logs'));
        $this->assertFalse($menus->contains('/migration'));
        $this->assertFalse($menus->contains('/settings'));
        $this->assertTrue($menus->contains('/operation-logs'));
    }

    public function test_user_can_update_own_profile_with_audit_log(): void
    {
        $user = User::factory()->create([
            'name' => '原姓名',
            'email' => 'old@example.test',
            'mobile' => '13800000000',
            'role' => 'unit',
        ]);

        Sanctum::actingAs($user);

        $this->putJson('/api/auth/profile', [
            'name' => '新姓名',
            'email' => 'new@example.test',
            'mobile' => '13900000000',
            'role' => 'admin',
        ])->assertOk()
            ->assertJsonPath('name', '新姓名')
            ->assertJsonPath('email', 'new@example.test')
            ->assertJsonPath('mobile', '13900000000')
            ->assertJsonPath('role', 'unit');

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => '新姓名',
            'email' => 'new@example.test',
            'mobile' => '13900000000',
            'role' => 'unit',
        ]);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'auth.profile_updated',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
    }

    public function test_user_cannot_update_profile_to_existing_email(): void
    {
        $user = User::factory()->create(['email' => 'self@example.test']);
        User::factory()->create(['email' => 'used@example.test']);

        Sanctum::actingAs($user);

        $this->putJson('/api/auth/profile', [
            'name' => $user->name,
            'email' => 'used@example.test',
            'mobile' => $user->mobile,
        ])->assertUnprocessable();
    }
}
