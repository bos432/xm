<?php

namespace App\Support;

use App\Models\Project;
use App\Models\ReviewDispatchRule;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class ReviewDispatchMatcher
{
    public function apply(Project $project, string $stage): ?array
    {
        if (! in_array($stage, [Role::DEPARTMENT, Role::EXPERT], true)) {
            return null;
        }

        $rule = $this->match($project, $stage);
        if (! $rule && $stage !== Role::EXPERT) {
            return null;
        }

        $users = $rule ? $this->activeTargetUsers($rule) : $this->activeExperts();
        if ($stage === Role::EXPERT && RuntimeConfig::boolValue('review.expert_assignment.random_enabled', true)) {
            $count = max(1, (int) ($rule?->expert_count ?: RuntimeConfig::intValue('review.expert_assignment.count', 3)));
            $users = $users->shuffle()->take($count)->values();
        }

        if ($stage === Role::EXPERT && $users->isEmpty()) {
            throw ValidationException::withMessages([
                'expert_assignment' => '没有可用专家账号，无法进入专家评审阶段，请先启用专家账号或调整派单规则。',
            ]);
        }

        $assignment = [
            'stage' => $stage,
            'rule_id' => $rule?->id,
            'rule_name' => $rule?->name ?: '专家随机分配',
            'auto_assign' => $stage === Role::EXPERT ? true : (bool) $rule?->auto_assign,
            'expert_count' => $stage === Role::EXPERT ? $users->count() : null,
            'recommended_user_ids' => $users->pluck('id')->all(),
            'recommended_users' => $users->map(fn (User $user): array => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role,
            ])->values()->all(),
            'assigned_user_ids' => ($stage === Role::EXPERT || (bool) $rule?->auto_assign) ? $users->pluck('id')->all() : [],
            'matched_at' => now()->toDateTimeString(),
        ];

        $metadata = is_array($project->metadata) ? $project->metadata : [];
        $metadata['review_dispatch']['assignments'][$stage] = $assignment;
        $project->metadata = $metadata;

        return $assignment;
    }

    public function userCanReview(Project $project, User $user, string $stage): bool
    {
        $assignment = $this->assignment($project, $stage);
        if ($stage !== Role::EXPERT && ! ($assignment['auto_assign'] ?? false)) {
            return true;
        }

        $assignedUserIds = array_map('intval', $assignment['assigned_user_ids'] ?? []);
        if ($stage === Role::EXPERT) {
            return $assignedUserIds !== [] && in_array((int) $user->id, $assignedUserIds, true);
        }

        return ! $assignedUserIds || in_array((int) $user->id, $assignedUserIds, true);
    }

    public function assignment(Project $project, string $stage): ?array
    {
        $metadata = is_array($project->metadata) ? $project->metadata : [];
        $assignment = $metadata['review_dispatch']['assignments'][$stage] ?? null;

        return is_array($assignment) ? $assignment : null;
    }

    private function match(Project $project, string $stage): ?ReviewDispatchRule
    {
        return ReviewDispatchRule::query()
            ->where('is_active', true)
            ->where('target_stage', $stage)
            ->orderBy('priority')
            ->orderByDesc('id')
            ->get()
            ->filter(fn (ReviewDispatchRule $rule): bool => $this->ruleMatchesProject($rule, $project))
            ->sortByDesc(fn (ReviewDispatchRule $rule): int => $this->specificity($rule))
            ->first();
    }

    private function activeTargetUsers(ReviewDispatchRule $rule): Collection
    {
        $ids = collect($rule->recommended_user_ids ?: [])
            ->map(fn ($id) => (int) $id)
            ->filter()
            ->unique()
            ->values();

        if ($ids->isEmpty()) {
            return collect();
        }

        return User::query()
            ->whereIn('id', $ids)
            ->where('role', $rule->target_stage)
            ->where('is_active', true)
            ->orderByRaw('FIELD(id, '.$ids->implode(',').')')
            ->get();
    }

    private function activeExperts(): Collection
    {
        return User::query()
            ->where('role', Role::EXPERT)
            ->where('is_active', true)
            ->orderBy('id')
            ->get();
    }

    private function ruleMatchesProject(ReviewDispatchRule $rule, Project $project): bool
    {
        $metadata = is_array($project->metadata) ? $project->metadata : [];

        return $this->fieldMatches($rule->management_unit, $metadata['management_unit'] ?? null)
            && $this->fieldMatches($rule->project_field, $metadata['field'] ?? null)
            && $this->fieldMatches($rule->research_direction, $metadata['research_direction'] ?? null)
            && $this->fieldMatches($rule->project_category, $project->category)
            && $this->fieldMatches($rule->project_type, $project->project_type);
    }

    private function fieldMatches(?string $expected, mixed $actual): bool
    {
        if ($expected === null || $expected === '') {
            return true;
        }

        return (string) $expected === (string) ($actual ?? '');
    }

    private function specificity(ReviewDispatchRule $rule): int
    {
        return collect([
            $rule->management_unit,
            $rule->project_field,
            $rule->research_direction,
            $rule->project_category,
            $rule->project_type,
        ])->filter(fn ($value) => $value !== null && $value !== '')->count();
    }
}
