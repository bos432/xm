<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PasswordUpdateTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_update_password_with_current_password(): void
    {
        $user = User::factory()->create([
            'username' => 'password-user',
            'password' => Hash::make('old-password'),
            'role' => 'unit',
        ]);

        Sanctum::actingAs($user);

        $this->putJson('/api/auth/password', [
            'current_password' => 'old-password',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertNoContent();

        $this->assertTrue(Hash::check('new-password', $user->refresh()->password));
        $this->assertFalse(Hash::check('old-password', $user->password));
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $user->id,
            'action' => 'auth.password_updated',
            'target_type' => User::class,
            'target_id' => $user->id,
        ]);
    }

    public function test_current_password_is_required_for_password_update(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('old-password'),
            'role' => 'unit',
        ]);

        Sanctum::actingAs($user);

        $this->putJson('/api/auth/password', [
            'current_password' => 'wrong-password',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertUnprocessable();

        $this->assertTrue(Hash::check('old-password', $user->refresh()->password));
    }

    public function test_password_confirmation_must_match(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('old-password'),
            'role' => 'unit',
        ]);

        Sanctum::actingAs($user);

        $this->putJson('/api/auth/password', [
            'current_password' => 'old-password',
            'password' => 'new-password',
            'password_confirmation' => 'different-password',
        ])->assertUnprocessable();
    }
}