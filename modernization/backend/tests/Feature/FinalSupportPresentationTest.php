<?php

namespace Tests\Feature;

use App\Models\Project;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class FinalSupportPresentationTest extends TestCase
{
    use RefreshDatabase;

    public static function supportCases(): array
    {
        return [
            'absent support' => [[], null, null],
            'empty support' => [['final_support' => []], null, null],
            'explicit no support' => [['final_support' => ['is_supported' => false]], false, 0.0],
            'itemized support' => [['final_support' => [
                'is_supported' => true,
                'subsidy_amount_wan' => 10,
                'interest_amount_wan' => 2,
                'other_amount_wan' => 1,
            ]], true, 13.0],
            'legacy subsidy' => [['final_support' => [
                'support_type' => 'subsidy',
                'support_amount_wan' => 38.5,
            ]], true, 38.5],
            'legacy no support' => [['final_support' => ['support_type' => 'none']], false, 0.0],
        ];
    }

    #[DataProvider('supportCases')]
    public function test_missing_support_is_not_presented_as_a_final_decision(
        array $metadata,
        ?bool $supported,
        ?float $amount,
    ): void {
        $user = User::factory()->create(['role' => 'super_admin']);
        $project = Project::factory()->create([
            'unit_id' => Unit::factory()->create()->id,
            'owner_id' => $user->id,
            'status' => Project::STATUS_REVIEWING,
            'current_reviewer_role' => 'expert',
            'metadata' => $metadata,
        ]);
        Sanctum::actingAs($user);

        $response = $this->getJson("/api/projects/{$project->id}")
            ->assertOk()
            ->assertJsonPath('final_support.is_supported', $supported);
        if ($amount === null) {
            $response->assertJsonPath('final_support.total_support_amount_wan', null)
                ->assertJsonPath('final_support.support_amount_wan', null)
                ->assertJsonPath('final_support.is_recommended', null);
        } else {
            $this->assertEquals($amount, $response->json('final_support.total_support_amount_wan'));
            $this->assertEquals($amount, $response->json('final_support.support_amount_wan'));
        }

        $this->assertSame($metadata, $project->fresh()->metadata);
        $this->assertSame(Project::STATUS_REVIEWING, $project->fresh()->status);
    }
}
