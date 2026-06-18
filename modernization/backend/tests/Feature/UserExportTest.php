<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_export_users_with_role_and_keyword_filters_without_passwords(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $unit = Unit::factory()->create(['name' => '浙江云平台公司']);
        $matched = User::factory()->create([
            'unit_id' => $unit->id,
            'role' => 'unit',
            'username' => 'cloud-applicant',
            'name' => '云平台申报员',
            'password' => 'do-not-export-password',
        ]);
        User::factory()->create([
            'role' => 'expert',
            'username' => 'cloud-expert',
            'name' => '云平台专家',
        ]);
        User::factory()->create([
            'role' => 'unit',
            'username' => 'factory-applicant',
            'name' => '制造申报员',
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/users/export.csv?role=unit&keyword=' . urlencode('云平台'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('账号ID', $csv);
        $this->assertStringContainsString($matched->username, $csv);
        $this->assertStringContainsString('浙江云平台公司', $csv);
        $this->assertStringNotContainsString('cloud-expert', $csv);
        $this->assertStringNotContainsString('factory-applicant', $csv);
        $this->assertStringNotContainsString('do-not-export-password', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'user.exported',
        ]);
    }

    public function test_admin_can_export_users_filtered_by_is_active(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $active = User::factory()->create(['username' => 'active-user', 'is_active' => true]);
        User::factory()->create(['username' => 'inactive-user', 'is_active' => false]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/users/export.csv?is_active=1')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('active-user', $csv);
        $this->assertStringNotContainsString('inactive-user', $csv);
    }

    public function test_non_admin_cannot_export_users(): void
    {
        $user = User::factory()->create(['role' => 'unit']);

        Sanctum::actingAs($user);

        $this->get('/api/users/export.csv')->assertForbidden();
    }
}
