<?php

namespace Tests\Feature;

use App\Models\DictionaryItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DictionaryManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_users_can_read_active_dictionary_items(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        DictionaryItem::create([
            'group' => 'project_type',
            'code' => 'key_support',
            'label' => '重点扶持',
            'sort_order' => 1,
            'is_active' => true,
        ]);
        DictionaryItem::create([
            'group' => 'project_type',
            'code' => 'disabled',
            'label' => '停用项',
            'sort_order' => 2,
            'is_active' => false,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/dictionaries?group=project_type')->assertOk();
        $codes = collect($response->json())->pluck('code');
        $this->assertTrue($codes->contains('key_support'));
        $this->assertFalse($codes->contains('disabled'));
    }

    public function test_admin_can_create_and_update_dictionary_item_with_audit_logs(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        Sanctum::actingAs($admin);

        $createResponse = $this->postJson('/api/dictionary-items', [
            'group' => 'project_type',
            'code' => 'innovation',
            'label' => '创新项目',
            'sort_order' => 10,
            'is_active' => true,
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('code', 'innovation');
        $itemId = $createResponse->json('id');
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'dictionary_item.created',
            'target_type' => DictionaryItem::class,
            'target_id' => $itemId,
        ]);

        $this->putJson("/api/dictionary-items/{$itemId}", [
            'group' => 'project_type',
            'code' => 'innovation',
            'label' => '创新示范项目',
            'sort_order' => 11,
            'is_active' => false,
        ])->assertOk()
            ->assertJsonPath('label', '创新示范项目')
            ->assertJsonPath('is_active', false);
        $this->assertDatabaseHas('operation_logs', [
            'user_id' => $admin->id,
            'action' => 'dictionary_item.updated',
            'target_type' => DictionaryItem::class,
            'target_id' => $itemId,
        ]);
    }

    public function test_non_admin_cannot_manage_dictionary_items(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        $item = DictionaryItem::create([
            'group' => 'project_type',
            'code' => 'basic',
            'label' => '基础项目',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        Sanctum::actingAs($user);

        $this->getJson('/api/dictionary-items')->assertForbidden();
        $this->postJson('/api/dictionary-items', [
            'group' => 'project_type',
            'code' => 'forbidden',
            'label' => '越权新增',
            'sort_order' => 1,
            'is_active' => true,
        ])->assertForbidden();
        $this->putJson("/api/dictionary-items/{$item->id}", [
            'group' => 'project_type',
            'code' => 'basic',
            'label' => '越权修改',
            'sort_order' => 1,
            'is_active' => true,
        ])->assertForbidden();
    }

    public function test_dictionary_code_is_unique_inside_group(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        DictionaryItem::create([
            'group' => 'project_type',
            'code' => 'basic',
            'label' => '基础项目',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        Sanctum::actingAs($admin);

        $this->postJson('/api/dictionary-items', [
            'group' => 'project_type',
            'code' => 'basic',
            'label' => '重复编码',
            'sort_order' => 2,
            'is_active' => true,
        ])->assertUnprocessable();
    }
}