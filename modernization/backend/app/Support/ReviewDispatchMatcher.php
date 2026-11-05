<?php

namespace App\Support;

use App\Models\Project;
use App\Models\ReviewDispatchRule;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class ReviewDispatchMatcher
{
    public function pendingQuery(User $user): Builder
    {
        $stage = Role::reviewerStageFor($user->role);

        return Project::query()
            ->where('current_reviewer_role', $stage)
            ->whereIn('status', [Project::STATUS_SUBMITTED, Project::STATUS_REVIEWING])
            ->when($stage === Role::EXPERT, function (Builder $query) use ($user): void {
                $query->whereDoesntHave('reviews', function (Builder $reviews) use ($user): void {
                    $reviews->currentRound()->where('stage', Role::EXPERT)->where('reviewer_id', $user->id);
                });
            });
    }

    public function apply(Project $project, string $stage): ?array
    {
        if (! in_array($stage, [Role::DEPARTMENT, Role::EXPERT], true)) {
            return null;
        }

        if ($assignment = $this->assignment($project, $stage)) {
            return $assignment;
        }

        $rule = $this->match($project, $stage);
        if (! $rule && $stage !== Role::EXPERT) {
            return null;
        }

        if ($stage === Role::EXPERT) {
            [$users, $error] = $this->selectExperts($project, $rule);
            if ($error !== null) {
                throw ValidationException::withMessages(['expert_assignment' => $error]);
            }
        } else {
            $users = $this->activeTargetUsers($rule);
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
        if ($stage === Role::EXPERT && ! $assignment) {
            $ids = $this->previewAssignment($project, $stage)['assigned_user_ids'];

            return $ids !== [] && in_array((int) $user->id, $ids, true);
        }
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

    public function previewAssignment(Project $project, string $stage): ?array
    {
        if ($this->assignment($project, $stage)) {
            return $this->assignment($project, $stage);
        }

        if ($stage !== Role::EXPERT) {
            return null;
        }

        $rule = $this->match($project, $stage);
        [$users, $error] = $this->selectExperts($project, $rule);

        return [
            'stage' => $stage,
            'rule_id' => $rule?->id,
            'rule_name' => $rule?->name ?: '专家随机分配',
            'auto_assign' => true,
            'expert_count' => $users->count(),
            'recommended_user_ids' => $users->pluck('id')->all(),
            'recommended_users' => $users->map(fn (User $user): array => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role,
            ])->values()->all(),
            'assigned_user_ids' => $users->pluck('id')->all(),
            'matched_at' => null,
            'preview' => true,
            'assignment_error' => $error,
        ];
    }

    private function selectExperts(Project $project, ?ReviewDispatchRule $rule): array
    {
        $testProject = $project->applicationBatch?->isE2e()
            || ($project->owner && $this->isTestUser($project->owner));
        $users = ($rule ? $this->activeTargetUsers($rule) : $this->activeExperts())
            ->filter(fn (User $user): bool => $this->isTestUser($user) === (bool) $testProject)
            ->values();
        $random = RuntimeConfig::boolValue('review.expert_assignment.random_enabled', true);
        $count = $random
            ? max(1, (int) ($rule?->expert_count ?: RuntimeConfig::intValue('review.expert_assignment.count', 3)))
            : 1;

        if ($users->count() < $count) {
            $pool = $testProject ? '测试专家池' : '正式专家池';

            return [collect(), $pool.'可用专家人数不足：需要'.$count.'人，当前'.$users->count().'人。请联系管理员补充启用专家或调整派单规则，审核尚未提交。'];
        }

        if ($random) {
            $users = $users->sortBy(fn (User $user): string => hash('sha256', $project->id.':expert:'.$user->id))
                ->take($count)->values();
        }

        return [$users, null];
    }

    private function isTestUser(User $user): bool
    {
        return filter_var($user->metadata['e2e'] ?? false, FILTER_VALIDATE_BOOLEAN)
            || preg_match('/^e2e_\d{8}(?:ops|_\d{6})_(unit|county|department|expert|admin|super_admin)(?:_\d+)?$/i', (string) $user->username) === 1;
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
            ->get()
            ->sortBy(fn (User $user): int => $ids->search((int) $user->id))
            ->values();
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
