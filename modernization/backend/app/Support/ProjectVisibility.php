<?php

namespace App\Support;

use App\Models\Project;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

class ProjectVisibility
{
    public function __construct(private readonly ReviewDispatchMatcher $dispatchMatcher) {}

    public function query(User $user): Builder
    {
        $query = Project::query();
        if ($user->role === Role::UNIT) {
            return $query->where('unit_id', $user->unit_id);
        }
        if ($user->role === Role::SUPER_ADMIN) {
            return $query;
        }
        $query->where('status', '<>', Project::STATUS_DRAFT);
        if ($this->isReviewer($user)) {
            $stage = Role::reviewerStageFor($user->role);
            $query->where(function (Builder $query) use ($stage, $user): void {
                $query->where('current_reviewer_role', $stage)
                    ->orWhereHas('reviews', fn (Builder $query) => $query
                        ->where('stage', $stage)->where('reviewer_id', $user->id));
            });
        }

        return $query;
    }

    public function allows(Project $project, User $user): bool
    {
        if (! Role::userCan($user, 'view_projects')) {
            return false;
        }
        if ($user->role === Role::UNIT) {
            return $project->unit_id === $user->unit_id;
        }
        if ($user->role === Role::SUPER_ADMIN) {
            return true;
        }
        if ($project->status === Project::STATUS_DRAFT) {
            return false;
        }
        if (! $this->isReviewer($user)) {
            return true;
        }

        $stage = Role::reviewerStageFor($user->role);

        // Past reviewers retain access across return rounds and later reassignment.
        return ($project->current_reviewer_role === $stage
                && $this->dispatchMatcher->userCanReview($project, $user, $stage))
            || $project->reviews()->where('stage', $stage)->where('reviewer_id', $user->id)->exists();
    }

    public function isReviewer(User $user): bool
    {
        return in_array($user->role, [Role::COUNTY, Role::DEPARTMENT, Role::EXPERT], true);
    }

    public function collect(Builder $query, User $user, ?int $limit = null): Collection
    {
        // Dispatch may use a legacy deterministic preview, so authorize full models
        // before applying limits; never create or replace assignment snapshots here.
        $rows = $query->lazy(100)->filter(fn (Project $project): bool => $this->allows($project, $user));
        if ($limit !== null) {
            $rows = $rows->take($limit);
        }

        return $rows->collect()->values();
    }
}
