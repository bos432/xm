<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PublicAuthRegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_unit_registration_creates_pending_unit_and_inactive_user(): void
    {
        $response = $this->postJson('/api/auth/register-unit', $this->registrationPayload());

        $response->assertCreated()
            ->assertJsonPath('unit.status', 'suspended')
            ->assertJsonPath('user.role', 'unit')
            ->assertJsonPath('user.is_active', false);

        $this->assertDatabaseHas('units', [
            'name' => 'Codex注册测试单位',
            'credit_code' => 'CODEX-REG-001',
            'status' => 'suspended',
        ]);
        $this->assertDatabaseHas('users', [
            'username' => 'codex-register-user',
            'email' => 'codex-register@example.test',
            'role' => 'unit',
            'is_active' => false,
        ]);

        $this->postJson('/api/auth/login', [
            'username' => 'codex-register-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertUnprocessable()
            ->assertJsonPath('message', '账号或密码错误');
    }

    public function test_admin_can_enable_registered_unit_user_and_user_can_create_project(): void
    {
        $this->postJson('/api/auth/register-unit', $this->registrationPayload())->assertCreated();
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);

        $unit = Unit::query()->where('credit_code', 'CODEX-REG-001')->firstOrFail();
        $user = User::query()->where('username', 'codex-register-user')->firstOrFail();

        $this->putJson('/api/units/'.$unit->id, [
            'name' => $unit->name,
            'credit_code' => $unit->credit_code,
            'contact_name' => $unit->contact_name,
            'contact_mobile' => $unit->contact_mobile,
            'email' => $unit->email,
            'address' => $unit->address,
            'region_code' => $unit->region_code,
            'status' => 'active',
        ])->assertOk();

        $this->putJson('/api/users/'.$user->id, [
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'mobile' => $user->mobile,
            'role' => $user->role,
            'unit_id' => $unit->id,
            'is_active' => true,
        ])->assertOk();

        $login = $this->postJson('/api/auth/login', [
            'username' => 'codex-register-user',
            'password' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ])->assertOk();

        Sanctum::actingAs($user->refresh());
        $this->postJson('/api/projects', [
            'title' => '注册单位申报测试项目',
            'category' => '科技项目',
            'project_type' => '重点扶持',
            'summary' => '注册审核通过后创建项目。',
            'budget_amount' => 10000,
        ])->assertCreated()
            ->assertJsonPath('status', 'draft');

        $this->assertNotEmpty($login->json('token'));
    }

    public function test_registration_validates_unique_username_email_and_captcha(): void
    {
        User::factory()->create([
            'username' => 'codex-register-user',
            'email' => 'codex-register@example.test',
        ]);

        $payload = $this->registrationPayload();
        $payload['captcha_answer'] = 999;

        $this->postJson('/api/auth/register-unit', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['username', 'email']);
    }

    public function test_forgot_password_does_not_expose_email_and_creates_token(): void
    {
        User::factory()->create(['email' => 'reset@example.test']);

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'reset@example.test',
            ...$this->validCaptchaPayload(),
        ])->assertOk()
            ->assertJsonPath('message', '如果邮箱已绑定账号，系统将发送密码重置邮件。');

        $this->assertDatabaseHas('password_reset_tokens', ['email' => 'reset@example.test']);

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'missing@example.test',
            ...$this->validCaptchaPayload(),
        ])->assertOk()
            ->assertJsonPath('message', '如果邮箱已绑定账号，系统将发送密码重置邮件。');
    }

    public function test_reset_password_updates_password_and_revokes_tokens(): void
    {
        $user = User::factory()->create([
            'email' => 'reset@example.test',
            'password' => Hash::make('old-password'),
        ]);
        $user->createToken('web');
        $token = 'plain-reset-token';

        DB::table('password_reset_tokens')->insert([
            'email' => 'reset@example.test',
            'token' => hash('sha256', $token),
            'created_at' => now(),
        ]);

        $this->postJson('/api/auth/reset-password', [
            'email' => 'reset@example.test',
            'token' => $token,
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertOk()
            ->assertJsonPath('message', '密码已重置，请重新登录。');

        $this->assertTrue(Hash::check('new-password', $user->refresh()->password));
        $this->assertDatabaseMissing('password_reset_tokens', ['email' => 'reset@example.test']);
        $this->assertSame(0, $user->tokens()->count());
    }

    private function registrationPayload(): array
    {
        return [
            'unit_name' => 'Codex注册测试单位',
            'credit_code' => 'CODEX-REG-001',
            'contact_name' => '注册联系人',
            'contact_mobile' => '13800000000',
            'email' => 'codex-register@example.test',
            'address' => '注册测试地址',
            'region_code' => 'test',
            'username' => 'codex-register-user',
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
            ...$this->validCaptchaPayload(),
        ];
    }
}
