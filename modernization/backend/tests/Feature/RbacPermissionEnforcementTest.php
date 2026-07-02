<?php

namespace Tests\Feature;

use App\Models\RbacPermission;
use App\Models\RbacRole;
use App\Models\Unit;
use App\Models\User;
use App\Support\Role as RoleSupport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RbacPermissionEnforcementTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_role_permissions_override_builtin_fallbacks(): void
    {
        $this->seedRbacRole(RoleSupport::UNIT, [
            'view_dashboard',
            'view_messages',
            'view_lifecycle',
            'view_task_books',
        ]);

        $unit = Unit::factory()->create();
        $user = User::factory()->create(['role' => RoleSupport::UNIT, 'unit_id' => $unit->id]);

        $permissions = RoleSupport::capabilitiesForUser($user);

        $this->assertContains('view_task_books', $permissions);
        $this->assertNotContains('view_expert_certifications', $permissions);

        Sanctum::actingAs($user);
        $this->getJson('/api/lifecycle/expert-certifications')->assertForbidden();
    }

    private function seedRbacRole(string $roleCode, array $permissionCodes): void
    {
        $permissionIds = [];
        foreach (RoleSupport::permissionsCatalog() as $permission) {
            $model = RbacPermission::query()->create($permission);
            $permissionIds[$permission['code']] = $model->id;
        }

        $role = RbacRole::query()->create([
            'code' => $roleCode,
            'name' => RoleSupport::builtInRoles()[$roleCode] ?? $roleCode,
            'is_builtin' => true,
            'is_active' => true,
        ]);

        $role->permissions()->sync(collect($permissionCodes)
            ->map(fn (string $code) => $permissionIds[$code] ?? null)
            ->filter()
            ->values()
            ->all());
    }
}
