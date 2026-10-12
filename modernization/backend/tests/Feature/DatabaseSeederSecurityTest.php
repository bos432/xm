<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DatabaseSeederSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeder_does_not_create_default_privileged_accounts_without_explicit_secrets(): void
    {
        config([
            'modernization.initial_admin_password' => '',
            'modernization.health_check_password' => '',
        ]);

        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseMissing('users', ['username' => 'admin']);
        $this->assertDatabaseMissing('users', ['username' => 'health_check_user']);
        $this->assertDatabaseMissing('users', ['username' => 'e2e_20260702_delivery_admin']);
    }

    public function test_seeder_preserves_existing_e2e_admin_account_state_and_password(): void
    {
        config([
            'modernization.initial_admin_password' => '',
            'modernization.health_check_password' => '',
        ]);

        $unit = Unit::factory()->create();
        $user = User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'e2e_20260702_delivery_admin',
            'role' => 'unit',
            'is_active' => false,
            'password' => Hash::make('Rotated-Secret-That-Stays-Private'),
            'metadata' => ['e2e' => true],
        ]);

        $this->seed(DatabaseSeeder::class);

        $user->refresh();
        $this->assertSame('unit', $user->role);
        $this->assertFalse($user->is_active);
        $this->assertTrue(Hash::check('Rotated-Secret-That-Stays-Private', $user->password));
    }

    public function test_seeder_rejects_legacy_weak_health_password_even_for_existing_account(): void
    {
        config([
            'modernization.initial_admin_password' => '',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'HealthCheck-2026',
        ]);

        $unit = Unit::factory()->create();
        $user = User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'health_check_user',
            'role' => 'unit',
            'password' => Hash::make('HealthCheck-2026'),
            'metadata' => ['health_check' => true],
        ]);

        try {
            $this->seed(DatabaseSeeder::class);
            $this->fail('Expected weak configured password to be rejected.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('HEALTH_CHECK_PASSWORD must contain at least 20 characters.', $exception->getMessage());
        }

        $user->refresh();
        $this->assertTrue(Hash::check('HealthCheck-2026', $user->password));
    }

    public function test_seeder_requires_strong_secrets_when_bootstrapping_accounts(): void
    {
        config([
            'modernization.initial_admin_password' => '',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'short',
        ]);

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('HEALTH_CHECK_PASSWORD must contain at least 20 characters.');

        $this->seed(DatabaseSeeder::class);
    }

    public function test_seeder_rotates_health_password_from_config_and_revokes_old_tokens(): void
    {
        config([
            'modernization.initial_admin_password' => '',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'New-Health-Password-Longer-Than-20',
        ]);

        $unit = Unit::factory()->create();
        $user = User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'health_check_user',
            'role' => 'unit',
            'password' => Hash::make('Existing-Health-Password'),
            'metadata' => ['health_check' => true],
        ]);
        $token = $user->createToken('old-health-token')->accessToken;

        $this->seed(DatabaseSeeder::class);

        $user->refresh();
        $this->assertTrue(Hash::check('New-Health-Password-Longer-Than-20', $user->password));
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token->id]);
    }
}
