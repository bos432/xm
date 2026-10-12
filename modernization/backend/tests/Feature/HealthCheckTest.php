<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HealthCheckTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_health_check_passes_with_valid_account(): void
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
            'metadata' => ['health_check' => true],
        ]);

        $this->artisan('health:login-check')->assertSuccessful();
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
