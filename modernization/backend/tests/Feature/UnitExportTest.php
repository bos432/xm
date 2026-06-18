<?php

namespace Tests\Feature;

use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UnitExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_export_units_with_keyword_filter(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $matched = Unit::factory()->create([
            'name' => '浙江云平台公司',
            'credit_code' => 'AAA001',
            'contact_name' => '张三',
        ]);
        Unit::factory()->create([
            'name' => '杭州制造公司',
            'credit_code' => 'BBB002',
            'contact_name' => '李四',
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/units/export.csv?keyword=' . urlencode('云平台'))
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('单位ID', $csv);
        $this->assertStringContainsString($matched->name, $csv);
        $this->assertStringNotContainsString('杭州制造公司', $csv);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'unit.exported',
        ]);
    }

    public function test_admin_can_export_units_with_status_filter(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $active = Unit::factory()->create(['name' => '正常单位', 'status' => 'active']);
        Unit::factory()->create(['name' => '暂停单位', 'status' => 'suspended']);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/units/export.csv?status=active')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString($active->name, $csv);
        $this->assertStringNotContainsString('暂停单位', $csv);
    }

    public function test_unit_export_neutralizes_spreadsheet_formulas(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Unit::factory()->create([
            'name' => '=HYPERLINK("https://example.test","打开")',
            'status' => 'active',
        ]);

        Sanctum::actingAs($admin);

        $csv = $this->get('/api/units/export.csv')
            ->assertOk()
            ->streamedContent();

        $this->assertStringContainsString('\'=HYPERLINK', $csv);
        $this->assertStringNotContainsString("\n=HYPERLINK", $csv);
    }

    public function test_non_admin_cannot_export_units(): void
    {
        $user = User::factory()->create(['role' => 'unit']);

        Sanctum::actingAs($user);

        $this->get('/api/units/export.csv')->assertForbidden();
    }
}
