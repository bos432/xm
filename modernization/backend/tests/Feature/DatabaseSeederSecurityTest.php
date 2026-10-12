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

    public function test_seeder_does_not_create_accounts_with_repository_default_passwords(): void
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

    public function test_seeder_creates_bootstrap_accounts_only_with_strong_explicit_secrets(): void
    {
        config([
            'modernization.initial_admin_username' => 'initial_super_admin',
            'modernization.initial_admin_password' => 'A-Strong-Initial-Admin-Secret-2026',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'A-Strong-Health-Secret-2026-Only',
        ]);

        $this->seed(DatabaseSeeder::class);

        $admin = User::query()->where('username', 'initial_super_admin')->firstOrFail();
        $health = User::query()->where('username', 'health_check_user')->firstOrFail();
        $this->assertSame('super_admin', $admin->role);
        $this->assertTrue(Hash::check('A-Strong-Initial-Admin-Secret-2026', $admin->password));
        $this->assertSame('unit', $health->role);
        $this->assertTrue((bool) ($health->metadata['health_check'] ?? false));
        $this->assertTrue(Hash::check('A-Strong-Health-Secret-2026-Only', $health->password));
    }

    public function test_seeder_does_not_overwrite_existing_admin_or_health_account_passwords(): void
    {
        config([
            'modernization.initial_admin_username' => 'admin',
            'modernization.initial_admin_password' => 'A-New-Admin-Secret-Longer-Than-20',
            'modernization.health_check_username' => 'health_check_user',
            'modernization.health_check_password' => 'A-New-Health-Secret-Longer-Than-20',
        ]);

        $unit = Unit::factory()->create();
        $admin = User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'admin',
            'role' => 'super_admin',
            'password' => Hash::make('Existing-Admin-Secret-Longer-Than-20'),
        ]);
        $health = User::factory()->create([
            'unit_id' => $unit->id,
            'username' => 'health_check_user',
            'role' => 'unit',
            'password' => Hash::make('Existing-Health-Secret-Longer-Than-20'),
            'metadata' => ['health_check' => true],
        ]);

        $this->seed(DatabaseSeeder::class);

        $this->assertTrue(Hash::check('Existing-Admin-Secret-Longer-Than-20', $admin->fresh()->password));
        $this->assertTrue(Hash::check('Existing-Health-Secret-Longer-Than-20', $health->fresh()->password));
    }

    public function test_seeder_rejects_weak_bootstrap_secrets(): void
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
}
