<?php

namespace Tests\Feature;

use App\Models\SecurityIpRule;
use App\Models\SecurityLock;
use App\Models\SystemText;
use App\Models\User;
use App\Support\SecurityService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class AdministrativeSurfaceRegressionTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_super_roles_cannot_read_or_write_administrative_surfaces(): void
    {
        $this->getJson('/api/security/policies')->assertUnauthorized();
        $this->getJson('/api/system-texts')->assertUnauthorized();
        foreach (['unit', 'county', 'department', 'expert', 'admin'] as $role) {
            Sanctum::actingAs(User::factory()->create(['role' => $role]));
            $this->getJson('/api/security/policies')->assertForbidden();
            $this->getJson('/api/security/events')->assertForbidden();
            $this->getJson('/api/security/blocked-identities')->assertForbidden();
            $this->putJson('/api/security/policies', [])->assertForbidden();
            $this->postJson('/api/security/blocked-identities', [])->assertForbidden();
            $this->getJson('/api/system-texts')->assertForbidden();
            $this->getJson('/api/system-texts/export.csv')->assertForbidden();
            $this->postJson('/api/system-texts', [])->assertForbidden();
        }
        $this->assertDatabaseCount('system_texts', 0);
        $this->assertDatabaseCount('security_locks', 0);
        $this->assertDatabaseCount('security_ip_rules', 0);
    }

    public function test_super_admin_text_override_reset_export_and_builtin_protection(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        $payload = ['key' => 'qa.delivery.notice', 'group' => 'qa', 'label' => 'QA notice',
            'default_value' => 'Default', 'value' => 'Override', 'is_active' => true, 'sort_order' => 0];
        $id = $this->postJson('/api/system-texts', $payload)->assertCreated()->json('id');
        $this->assertSame('Override', $this->getJson('/api/public/system-texts')->assertOk()->json('texts')['qa.delivery.notice']);
        $this->putJson('/api/system-texts/'.$id, array_replace($payload, ['is_active' => false]))->assertOk();
        $this->assertSame('', $this->getJson('/api/public/system-texts')->assertOk()->json('texts')['qa.delivery.notice']);
        $this->postJson('/api/system-texts/'.$id.'/reset')->assertOk()->assertJsonPath('value', null);
        $this->assertSame('Default', $this->getJson('/api/public/system-texts')->assertOk()->json('texts')['qa.delivery.notice']);
        $this->postJson('/api/system-texts', $payload)->assertUnprocessable()->assertJsonValidationErrors('key');
        $this->postJson('/api/system-texts', array_replace($payload, ['key' => 'invalid key', 'value' => str_repeat('x', 20001)]))
            ->assertUnprocessable()->assertJsonValidationErrors(['key', 'value']);
        $this->getJson('/api/system-texts?group=qa&keyword=delivery&builtin=0')->assertOk()->assertJsonPath('data.total', 1);
        $csv = $this->get('/api/system-texts/export.csv?group=qa&keyword=delivery')->assertOk()->streamedContent();
        $this->assertStringContainsString('qa.delivery.notice', $csv);
        $builtin = SystemText::query()->where('is_builtin', true)->firstOrFail();
        $originalKey = $builtin->key;
        $originalDefault = $builtin->default_value;
        $this->putJson('/api/system-texts/'.$builtin->id, array_replace($payload, ['key' => 'qa.rekey', 'default_value' => 'Changed']))->assertOk();
        $this->assertSame($originalKey, $builtin->fresh()->key);
        $this->assertSame($originalDefault, $builtin->fresh()->default_value);
        $this->deleteJson('/api/system-texts/'.$builtin->id)->assertUnprocessable();
        $this->deleteJson('/api/system-texts/'.$id)->assertNoContent();
        $this->assertDatabaseMissing('system_texts', ['id' => $id]);
    }

    public function test_super_admin_security_lock_rule_and_policy_roundtrip(): void
    {
        $admin = User::factory()->create(['role' => 'super_admin']);
        Sanctum::actingAs($admin);
        $defaults = $this->getJson('/api/security/policies')->assertOk()
            ->assertJsonPath('login_failure_threshold', 5)->assertJsonPath('lock_minutes', 30)->json();
        $this->putJson('/api/security/policies', array_replace($defaults, ['lock_minutes' => 0]))
            ->assertUnprocessable()->assertJsonValidationErrors('lock_minutes');
        $this->getJson('/api/security/policies')->assertOk()->assertJsonPath('lock_minutes', 30);
        $this->putJson('/api/security/policies', array_replace($defaults, ['login_throttle_relaxed' => true,
            'login_throttle_relaxed_until' => now()->addMinutes(5)->toIso8601String(), 'login_throttle_relaxed_reason' => 'QA isolation']))
            ->assertOk()->assertJsonPath('login_throttle_relaxed_active', true)->assertJsonPath('login_throttle_relaxed_by', $admin->username);
        $this->getJson('/api/security/events?type=security.login_throttle_relaxed_enabled&severity=medium&keyword='.$admin->username)
            ->assertOk()->assertJsonPath('total', 1);
        $lockId = $this->postJson('/api/security/blocked-identities', ['kind' => 'lock', 'identity_type' => 'username', 'identity_value' => 'qa-lock'])
            ->assertCreated()->json('id');
        $this->getJson('/api/security/blocked-identities')->assertOk()->assertJsonPath('locks.total', 1);
        $this->postJson('/api/security/locks/'.$lockId.'/release')->assertOk()->assertJsonPath('is_active', false);
        $this->deleteJson('/api/security/blocked-identities/'.$lockId)->assertNoContent();
        $this->assertFalse(SecurityLock::findOrFail($lockId)->is_active);
        $ruleId = $this->postJson('/api/security/blocked-identities', ['kind' => 'ip_rule', 'rule_type' => 'blacklist', 'cidr' => '192.0.2.0/24'])
            ->assertCreated()->json('id');
        $this->assertSame('192.0.2.0/24', SecurityIpRule::findOrFail($ruleId)->cidr);
        $this->deleteJson('/api/security/blocked-identities/rule:'.$ruleId)->assertNoContent();
        $this->assertDatabaseMissing('security_ip_rules', ['id' => $ruleId]);
    }

    public function test_invalid_ip_rules_are_rejected_without_creating_rows(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin']));
        foreach (['not-an-ip', '192.0.2.1/33', '2001:db8::/129', '192.0.2.1/-1', '192.0.2.1/abc', '192.0.2.1/24/1'] as $cidr) {
            $this->postJson('/api/security/blocked-identities', ['kind' => 'ip_rule', 'rule_type' => 'blacklist', 'cidr' => $cidr])
                ->assertUnprocessable()->assertJsonValidationErrors('cidr');
        }
        $this->assertDatabaseCount('security_ip_rules', 0);
        foreach (['192.0.2.1', '192.0.2.0/24', '2001:db8::1', '2001:db8::/64'] as $cidr) {
            $this->postJson('/api/security/blocked-identities', ['kind' => 'ip_rule', 'rule_type' => 'blacklist', 'cidr' => $cidr])->assertCreated();
        }
        $this->assertDatabaseCount('security_ip_rules', 4);
    }

    public function test_ipv6_blacklist_blocks_inside_subnet_and_allows_outside(): void
    {
        SecurityIpRule::create(['type' => 'blacklist', 'cidr' => '2001:db8::/64']);
        $service = app(SecurityService::class);
        $service->assertLoginAllowed(Request::create('/api/auth/login', 'POST', [], [], [], ['REMOTE_ADDR' => '2001:db8:1::1']));
        try {
            $service->assertLoginAllowed(Request::create('/api/auth/login', 'POST', [], [], [], ['REMOTE_ADDR' => '2001:db8::123']));
            $this->fail('IPv6 subnet blacklist did not block login');
        } catch (HttpException $exception) {
            $this->assertSame(403, $exception->getStatusCode());
        }
        $this->assertDatabaseHas('security_events', ['type' => 'security.ip_blacklisted', 'ip_address' => '2001:db8::123']);
    }

    public function test_malformed_legacy_prefix_does_not_block_unrelated_addresses(): void
    {
        SecurityIpRule::create(['type' => 'blacklist', 'cidr' => '192.0.2.0/abc']);
        app(SecurityService::class)->assertLoginAllowed(Request::create('/api/auth/login', 'POST', [], [], [], ['REMOTE_ADDR' => '198.51.100.1']));
        $this->assertDatabaseCount('security_events', 0);
    }

    public function test_host_and_subnet_boundaries_preserve_ip_family_and_active_rules(): void
    {
        $cases = [
            ['192.0.2.0/24', '192.0.2.255', true],
            ['192.0.2.0/24', '192.0.3.0', false],
            ['192.0.2.1/32', '192.0.2.1', true],
            ['192.0.2.1/32', '192.0.2.2', false],
            ['0.0.0.0/0', '198.51.100.1', true],
            ['0.0.0.0/0', '2001:db8::1', false],
            ['2001:db8::1/128', '2001:0db8:0:0:0:0:0:1', true],
            ['2001:db8::1/128', '2001:db8::2', false],
            ['::/0', '2001:db8::1', true],
            ['::/0', '192.0.2.1', false],
        ];
        foreach ($cases as [$cidr, $ip, $blocked]) {
            SecurityIpRule::query()->delete();
            SecurityIpRule::create(['type' => 'blacklist', 'cidr' => $cidr]);
            $actual = false;
            try {
                app(SecurityService::class)->assertLoginAllowed(Request::create('/api/auth/login', 'POST', [], [], [], ['REMOTE_ADDR' => $ip]));
            } catch (HttpException $exception) {
                $this->assertSame(403, $exception->getStatusCode());
                $actual = true;
            }
            $this->assertSame($blocked, $actual, $cidr.' against '.$ip);
        }
        SecurityIpRule::query()->update(['is_active' => false]);
        app(SecurityService::class)->assertLoginAllowed(Request::create('/api/auth/login', 'POST', [], [], [], ['REMOTE_ADDR' => '2001:db8::1']));
    }
}
