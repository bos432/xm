<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class HealthCheckTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_health_check_passes_with_valid_account(): void
    {
        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        $this->artisan('health:login-check', [
            '--username' => 'health_check_user',
            '--password' => 'HealthCheck-2026',
        ])->assertSuccessful();
    }

    public function test_login_health_check_fails_with_wrong_password(): void
    {
        User::factory()->create([
            'username' => 'health_check_user',
            'password' => Hash::make('HealthCheck-2026'),
            'role' => 'unit',
            'is_active' => true,
            'metadata' => ['health_check' => true],
        ]);

        $this->artisan('health:login-check', [
            '--username' => 'health_check_user',
            '--password' => 'Wrong-Password',
        ])->assertFailed();
    }

    public function test_failed_jobs_count_command_does_not_require_tinker(): void
    {
        $this->artisan('queue:failed-count')
            ->expectsOutput('0')
            ->assertSuccessful();
    }
}
