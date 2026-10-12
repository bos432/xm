<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HealthCheckTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_health_check_passes_with_valid_account(): void
    {
        config(['app.url' => 'https://nxm.zlck888.com']);
        config([
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        Http::fake([
            'https://nxm.zlck888.com/api/auth/captcha' => Http::response([
                'captcha_id' => 'health-captcha',
                'question' => '6 + 7 = ?',
            ]),
            'https://nxm.zlck888.com/api/auth/login' => Http::response(['token' => 'health-token']),
            'https://nxm.zlck888.com/api/auth/logout' => Http::response([], 204),
        ]);

        $this->artisan('health:login-check')->assertSuccessful();
        Http::assertSent(fn ($request) => $request->url() === 'https://nxm.zlck888.com/api/auth/login'
            && $request['captcha_answer'] === 13
            && $request['password'] === 'HealthCheck-2026');
        Http::assertSent(fn ($request) => $request->url() === 'https://nxm.zlck888.com/api/auth/logout'
            && $request->hasHeader('Authorization', 'Bearer health-token'));
    }

    public function test_login_health_check_fails_with_wrong_password(): void
    {
        config([
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'Wrong-Password',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        $this->artisan('health:login-check')->assertFailed();
    }

    public function test_login_health_check_accepts_explicit_credentials_for_deploy_script_compatibility(): void
    {
        config(['app.url' => 'https://nxm.zlck888.com']);
        config([
            'modernization.health_check_username' => 'configured-user',
            'modernization.health_check_password' => 'configured-password',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        Http::fake([
            'https://nxm.zlck888.com/api/auth/captcha' => Http::response([
                'captcha_id' => 'health-captcha',
                'question' => '6 + 7 = ?',
            ]),
            'https://nxm.zlck888.com/api/auth/login' => Http::response(['token' => 'health-token']),
            'https://nxm.zlck888.com/api/auth/logout' => Http::response([], 204),
        ]);

        $this->artisan('health:login-check', [
            '--username' => 'health_check_user',
            '--password' => 'HealthCheck-2026',
        ])->assertSuccessful();
    }

    public function test_login_health_check_rejects_accounts_not_marked_for_health_checks(): void
    {
        config([
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => [],
        ]);

        $this->artisan('health:login-check')->assertFailed();
    }

    public function test_login_health_check_requires_https_app_url(): void
    {
        config([
            'app.url' => 'http://nxm.zlck888.com',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        Http::fake();
        $this->artisan('health:login-check')->assertFailed();
        Http::assertNothingSent();
    }

    public function test_login_health_check_rejects_non_production_https_host(): void
    {
        config([
            'app.url' => 'https://attacker.example',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        Http::fake();
        $this->artisan('health:login-check')->assertFailed();
        Http::assertNothingSent();
    }

    public function test_login_health_check_rejects_unrecognized_captcha_question(): void
    {
        $this->configureHealthAccount();
        Http::fake([
            'https://nxm.zlck888.com/api/auth/captcha' => Http::response([
                'captcha_id' => 'health-captcha',
                'question' => '6 + 7 + 2026 = ?',
            ]),
        ]);

        $this->artisan('health:login-check')->assertFailed();
        Http::assertSentCount(1);
    }

    public function test_login_health_check_fails_when_logout_does_not_succeed(): void
    {
        $this->configureHealthAccount();
        Http::fake([
            'https://nxm.zlck888.com/api/auth/captcha' => Http::response([
                'captcha_id' => 'health-captcha',
                'question' => '6 + 7 = ?',
            ]),
            'https://nxm.zlck888.com/api/auth/login' => Http::response(['token' => 'health-token']),
            'https://nxm.zlck888.com/api/auth/logout' => Http::response(['message' => 'failed'], 500),
        ]);

        $this->artisan('health:login-check')->assertFailed();
        Http::assertSent(fn ($request) => $request->url() === 'https://nxm.zlck888.com/api/auth/logout'
            && $request->hasHeader('Authorization', 'Bearer health-token'));
    }

    private function configureHealthAccount(): void
    {
        config([
            'app.url' => 'https://nxm.zlck888.com',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);
    }

    public function test_health_check_account_cannot_access_business_api_but_can_logout(): void
    {
        $unit = Unit::factory()->create();
        $user = User::factory()->create([
            'unit_id' => $unit->id,
            'role' => 'unit',
            'metadata' => ['health_check' => true],
        ]);

        Sanctum::actingAs($user);

        $this->getJson('/api/projects')->assertForbidden();
        $this->postJson('/api/auth/logout')->assertNoContent();
    }

    public function test_failed_jobs_count_command_does_not_require_tinker(): void
    {
        $this->artisan('queue:failed-count')
            ->expectsOutput('0')
            ->assertSuccessful();
    }
}
