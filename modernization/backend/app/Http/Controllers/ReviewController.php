<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\RichTextSanitizer;
use App\Support\Role;
use App\Support\ReviewDispatchMatcher;
use App\Support\ReviewScoreCriteria;
use App\Support\RuntimeConfig;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ReviewController extends Controller
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly ReviewDispatchMatcher $dispatchMatcher,
    )
    {
    }

    public function tasks(Request $request)
    {
        $this->authorizeReviewer($request);

        $stage = Role::reviewerStageFor($request->user()->role);
        $query = Project::query()
            ->where('current_reviewer_role', Role::reviewerStageFor($request->user()->role))
            ->whereIn('status', [Project::STATUS_SUBMITTED, Project::STATUS_REVIEWING])
            ->when($request->filled('project_id'), function ($query) use ($request) {
                $query->where('id', $request->query('project_id'));
            })
            ->when($request->filled('category'), function ($query) use ($request) {
                $query->where('category', $request->query('category'));
            })
            ->when($request->filled('project_type'), function ($query) use ($request) {
                $query->where('project_type', $request->query('project_type'));
            })
            ->when($request->filled('keyword'), function ($query) use ($request) {
                $keyword = $request->query('keyword');
                $query->where(function ($query) use ($keyword) {
                    $query->where('title', 'like', "%{$keyword}%")
                        ->orWhereHas('unit', function ($query) use ($keyword) {
                            $query->where('name', 'like', "%{$keyword}%");
                        })
                        ->orWhereHas('owner', function ($query) use ($keyword) {
                            $query->where('username', 'like', "%{$keyword}%");
                        });
                });
            })
            ->with(['unit', 'owner'])
            ->orderByRaw('COALESCE(submitted_at, updated_at, created_at) desc')
            ->orderByDesc('id');

        $visible = $query->get()
            ->map(function (Project $project) use ($stage): Project {
                if ($stage === Role::EXPERT && ! $this->dispatchMatcher->assignment($project, Role::EXPERT)) {
                    $assignment = $this->dispatchMatcher->apply($project, Role::EXPERT);
                    if ($assignment) {
                        $project->save();
                        $project->refresh();
                    }
                }

                return $project;
            })
            ->filter(fn (Project $project): bool => $this->dispatchMatcher->userCanReview($project, $request->user(), $stage))
            ->map(fn (Project $project): Project => $this->attachDispatchAssignment($project, $stage))
            ->values();

        $page = max((int) $request->query('page', 1), 1);
        $perPage = 20;

        return new LengthAwarePaginator(
            $visible->forPage($page, $perPage)->values(),
            $visible->count(),
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $request->query()]
        );
    }

    public function results(Request $request)
    {
        $this->authorizeReviewer($request);

        $query = ProjectReview::query()
            ->with(['project.unit', 'project.owner', 'reviewer'])
            ->orderByDesc('reviewed_at')
            ->orderByDesc('id');

        if (! in_array($request->user()->role, Role::adminRoles(), true)) {
            $query->where('stage', Role::reviewerStageFor($request->user()->role));
        } elseif ($stage = $request->query('stage')) {
            $query->where('stage', $stage);
        }

        if ($decision = $request->query('decision')) {
            $query->where('decision', $decision);
        }

        if ($request->filled('project_id')) {
            $query->where('project_id', $request->query('project_id'));
        }

        if ($request->filled('score_min')) {
            $query->where('score', '>=', $request->query('score_min'));
        }

        if ($request->filled('score_max')) {
            $query->where('score', '<=', $request->query('score_max'));
        }

        if ($request->filled('category')) {
            $query->whereHas('project', function ($query) use ($request) {
                $query->where('category', $request->query('category'));
            });
        }

        if ($request->filled('project_type')) {
            $query->whereHas('project', function ($query) use ($request) {
                $query->where('project_type', $request->query('project_type'));
            });
        }

        if ($request->filled('keyword')) {
            $keyword = $request->query('keyword');
            $query->where(function ($query) use ($keyword) {
                $query->where('comment', 'like', "%{$keyword}%")
                    ->orWhereHas('project', function ($query) use ($keyword) {
                        $query->where('title', 'like', "%{$keyword}%")
                            ->orWhereHas('unit', function ($query) use ($keyword) {
                                $query->where('name', 'like', "%{$keyword}%");
                            })
                            ->orWhereHas('owner', function ($query) use ($keyword) {
                                $query->where('username', 'like', "%{$keyword}%");
                            });
                    });
            });
        }

        return $query->paginate(20);
    }

    public function store(Request $request, Project $project)
    {
        $this->authorizeReviewer($request);

        $stage = Role::reviewerStageFor($request->user()->role);
        if ($project->current_reviewer_role !== $stage) {
            abort(403, '当前项目不属于你的审核阶段');
        }

        if ($stage === Role::EXPERT && ! $this->dispatchMatcher->assignment($project, Role::EXPERT)) {
            $assignment = $this->dispatchMatcher->apply($project, Role::EXPERT);
            if ($assignment) {
                $project->save();
                $project->refresh();
            }
        }

        if (! $this->dispatchMatcher->userCanReview($project, $request->user(), $stage)) {
            abort(403, '该项目已自动派单给其他审核人员');
        }

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject,recommend,accept'],
            'score' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'comment' => ['nullable', 'string', 'max:3000'],
            'metadata' => ['nullable', 'array'],
            'metadata.score_criteria' => ['nullable', 'array'],
            'metadata.final_support' => ['nullable', 'array'],
            'metadata.final_support.is_recommended' => ['nullable', 'boolean'],
            'metadata.final_support.is_supported' => ['nullable', 'boolean'],
            'metadata.final_support.support_type' => ['nullable', 'in:subsidy,interest,other,none'],
            'metadata.final_support.support_amount_wan' => ['nullable', 'numeric', 'min:0'],
            'metadata.final_support.recommended_experts' => ['nullable', 'string', 'max:500'],
            'metadata.final_support.subsidy_amount_wan' => ['nullable', 'numeric', 'min:0'],
            'metadata.final_support.interest_amount_wan' => ['nullable', 'numeric', 'min:0'],
            'metadata.final_support.other_amount_wan' => ['nullable', 'numeric', 'min:0'],
            'metadata.final_support.other_support_note' => ['nullable', 'string', 'max:500'],
        ]);
        $data['comment'] = RichTextSanitizer::clean($data['comment'] ?? null);

        $this->ensureStageScoreAllowed($stage, $data, $request);

        if ($stage === Role::EXPERT && $this->hasExistingExpertReview($project, $request->user()->id)) {
            return response()->json(['message' => '你已提交过该项目专家评分，不能重复提交'], 422);
        }

        if ($stage === Role::EXPERT) {
            $data = ReviewScoreCriteria::applyExpertScores($data);
        }

        if ($stage === Role::ADMIN) {
            $data = $this->applyFinalSupportMetadata($data, $project, $request);
        }

        [$review, $assignment] = DB::transaction(function () use ($request, $project, $stage, $data): array {
            $review = ProjectReview::create($data + [
                'project_id' => $project->id,
                'reviewer_id' => $request->user()->id,
                'stage' => $stage,
                'reviewed_at' => now(),
            ]);

            $nextState = $this->nextProjectState($project, $data['decision']);
            if ($stage === Role::ADMIN && $data['decision'] === 'accept') {
                $projectMetadata = is_array($project->metadata) ? $project->metadata : [];
                $projectMetadata['final_support'] = $data['metadata']['final_support'] ?? [];
                $nextState['metadata'] = $projectMetadata;
            }

            $project->update($nextState);
            $project->refresh();

            $assignment = null;
            if ($project->current_reviewer_role) {
                $assignment = $this->dispatchMatcher->apply($project, $project->current_reviewer_role);
                if ($assignment) {
                    $project->save();
                    $project->refresh();
                }
            }

            return [$review, $assignment];
        });

        $this->auditLogger->record($request, 'project.reviewed', $review, [
            'project_id' => $project->id,
            'decision' => $data['decision'],
            'next_status' => $project->status,
            'next_reviewer_role' => $project->current_reviewer_role,
        ]);

        Message::create([
            'recipient_id' => $project->owner_id,
            'project_id' => $project->id,
            'type' => 'review',
            'title' => '项目审核状态更新',
            'body' => '审核结果：'.$data['decision'].'。'.($data['comment'] ?? ''),
        ]);

        if ($project->current_reviewer_role) {
            $this->notifyReviewRecipients($project, $project->current_reviewer_role, $assignment, '收到待审项目', $this->dispatchMessageBody($project, $assignment));
        }

        return response()->json([
            'review' => $review,
            'project' => $project->refresh(),
        ], 201);
    }

    private function authorizeReviewer(Request $request): void
    {
        if (! Role::userCan($request->user(), 'review_projects')) {
            abort(403, '无权处理审核任务');
        }
    }

    private function notifyRole(Project $project, string $role, string $title, string $body): void
    {
        User::query()
            ->where(function ($query) use ($role): void {
                $query->where('role', $role);
                if ($role === Role::ADMIN) {
                    $query->orWhere('role', Role::SUPER_ADMIN);
                }
            })
            ->where('is_active', true)
            ->each(function (User $user) use ($project, $title, $body): void {
                Message::create([
                    'recipient_id' => $user->id,
                    'project_id' => $project->id,
                    'type' => 'review',
                    'title' => $title,
                    'body' => $body,
                ]);
            });
    }

    private function notifyUsers(Project $project, array $userIds, string $title, string $body): void
    {
        if ($userIds === []) {
            return;
        }

        User::query()
            ->whereIn('id', array_values(array_unique(array_map('intval', $userIds))))
            ->where('is_active', true)
            ->each(function (User $user) use ($project, $title, $body): void {
                Message::create([
                    'recipient_id' => $user->id,
                    'project_id' => $project->id,
                    'type' => 'review',
                    'title' => $title,
                    'body' => $body,
                ]);
            });
    }

    private function notifyReviewRecipients(Project $project, string $role, ?array $assignment, string $title, string $body): void
    {
        $assignedUserIds = array_map('intval', $assignment['assigned_user_ids'] ?? []);
        if ($role === Role::EXPERT && $assignedUserIds !== []) {
            $reviewedUserIds = $project->reviews()
                ->where('stage', Role::EXPERT)
                ->pluck('reviewer_id')
                ->map(fn ($id) => (int) $id)
                ->all();
            $this->notifyUsers($project, array_values(array_diff($assignedUserIds, $reviewedUserIds)), $title, $body);

            return;
        }

        $this->notifyRole($project, $role, $title, $body);
    }

    private function attachDispatchAssignment(Project $project, string $stage): Project
    {
        $project->setAttribute('dispatch_assignment', $this->dispatchMatcher->assignment($project, $stage));

        return $project;
    }

    private function dispatchMessageBody(Project $project, ?array $assignment): string
    {
        $body = '项目“'.$project->title.'”已流转到你的审核阶段。';
        if (! $assignment) {
            return $body;
        }

        $names = collect($assignment['recommended_users'] ?? [])
            ->map(fn (array $user): string => $user['name'] ?: $user['username'])
            ->filter()
            ->implode('、');

        if ($names === '') {
            return $body;
        }

        return $body.($assignment['auto_assign'] ? '已自动派单给：' : '系统推荐处理人：').$names.'。';
    }

    private function applyFinalSupportMetadata(array $data, Project $project, Request $request): array
    {
        if (($data['decision'] ?? null) !== 'accept') {
            return $data;
        }

        $metadata = is_array($data['metadata'] ?? null) ? $data['metadata'] : [];
        $input = is_array($metadata['final_support'] ?? null) ? $metadata['final_support'] : [];
        $isSupported = filter_var($input['is_supported'] ?? true, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        $isRecommended = filter_var($input['is_recommended'] ?? true, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        $supportType = (string) ($input['support_type'] ?? ($isSupported === false ? 'none' : 'subsidy'));

        if ($isSupported === false) {
            $supportType = 'none';
        } elseif (! in_array($supportType, ['subsidy', 'interest', 'other'], true)) {
            $supportType = 'subsidy';
        }

        $metadata['final_support'] = [
            'is_recommended' => $isRecommended ?? true,
            'is_supported' => $isSupported ?? true,
            'support_type' => $supportType,
            'support_amount_wan' => round((float) ($input['support_amount_wan'] ?? 0), 2),
            'subsidy_amount_wan' => $this->supportAmount($input, 'subsidy_amount_wan', $supportType === 'subsidy' ? ($input['support_amount_wan'] ?? 0) : 0, $isSupported),
            'interest_amount_wan' => $this->supportAmount($input, 'interest_amount_wan', $supportType === 'interest' ? ($input['support_amount_wan'] ?? 0) : 0, $isSupported),
            'other_amount_wan' => $this->supportAmount($input, 'other_amount_wan', $supportType === 'other' ? ($input['support_amount_wan'] ?? 0) : 0, $isSupported),
            'other_support_note' => trim((string) ($input['other_support_note'] ?? '')),
            'recommended_experts' => $this->recommendedExpertNames($project),
            'reviewed_by' => $request->user()->id,
            'reviewed_by_name' => $request->user()->name ?: $request->user()->username,
            'reviewed_at' => now()->toDateTimeString(),
        ];
        $metadata['final_support']['total_support_amount_wan'] = round(
            $metadata['final_support']['subsidy_amount_wan']
            + $metadata['final_support']['interest_amount_wan']
            + $metadata['final_support']['other_amount_wan'],
            2
        );
        $metadata['final_support']['support_amount_wan'] = $metadata['final_support']['total_support_amount_wan'];

        $data['metadata'] = $metadata;

        return $data;
    }

    private function supportAmount(array $input, string $key, mixed $legacyValue, bool|null $isSupported): float
    {
        if ($isSupported === false) {
            return 0.0;
        }

        return round((float) ($input[$key] ?? $legacyValue ?? 0), 2);
    }

    private function recommendedExpertNames(Project $project): string
    {
        $project->loadMissing(['reviews.reviewer']);

        return $project->reviews
            ->where('stage', Role::EXPERT)
            ->where('decision', 'recommend')
            ->map(fn (ProjectReview $review): string => $review->reviewer?->name ?: $review->reviewer?->username ?: '')
            ->filter()
            ->unique()
            ->implode('、');
    }

    private function nextProjectState(Project $project, string $decision): array
    {
        if ($decision === 'return') {
            return ['status' => Project::STATUS_RETURNED, 'current_reviewer_role' => null];
        }

        if ($decision === 'reject') {
            return ['status' => Project::STATUS_REJECTED, 'current_reviewer_role' => null];
        }

        if ($project->current_reviewer_role === Role::EXPERT && ! $this->expertStageComplete($project)) {
            return ['status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => Role::EXPERT];
        }

        $flow = [Role::COUNTY => Role::DEPARTMENT, Role::DEPARTMENT => Role::EXPERT, Role::EXPERT => Role::ADMIN];
        $nextRole = $flow[$project->current_reviewer_role] ?? null;

        return $nextRole
            ? ['status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => $nextRole]
            : ['status' => Project::STATUS_APPROVED, 'current_reviewer_role' => null];
    }

    private function expertStageComplete(Project $project): bool
    {
        $assignment = $this->dispatchMatcher->assignment($project, Role::EXPERT);
        $assignedUserIds = array_values(array_unique(array_map('intval', $assignment['assigned_user_ids'] ?? [])));
        if ($assignedUserIds === []) {
            return false;
        }

        $reviewedUserIds = $project->reviews()
            ->where('stage', Role::EXPERT)
            ->whereIn('reviewer_id', $assignedUserIds)
            ->whereIn('decision', ['approve', 'recommend', 'accept'])
            ->pluck('reviewer_id')
            ->map(fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();

        return count($reviewedUserIds) >= count($assignedUserIds);
    }

    private function hasExistingExpertReview(Project $project, int $userId): bool
    {
        return $project->reviews()
            ->where('stage', Role::EXPERT)
            ->where('reviewer_id', $userId)
            ->exists();
    }

    private function ensureStageScoreAllowed(string $stage, array $data, Request $request): void
    {
        if ($stage === Role::EXPERT) {
            return;
        }

        if ($this->scoreEnabledForStage($stage)) {
            return;
        }

        $hasScore = $request->filled('score') || data_get($data, 'metadata.score_criteria');
        if ($hasScore) {
            throw ValidationException::withMessages([
                'score' => $this->stageLabel($stage).'未开启评分，不能提交评分。',
            ]);
        }
    }

    private function scoreEnabledForStage(string $stage): bool
    {
        return RuntimeConfig::boolValue('review.score_enabled.'.$stage, $stage === Role::EXPERT);
    }

    private function stageLabel(string $stage): string
    {
        return [
            Role::COUNTY => '区县审核',
            Role::DEPARTMENT => '部门审核',
            Role::EXPERT => '专家评审',
            Role::ADMIN => '管理员终审',
        ][$stage] ?? '当前阶段';
    }
}
