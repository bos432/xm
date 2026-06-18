<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\Project;
use App\Models\ProjectReview;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function tasks(Request $request)
    {
        $this->authorizeReviewer($request);

        return Project::query()
            ->where('current_reviewer_role', $request->user()->role)
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
            ->latest('submitted_at')
            ->paginate(20);
    }

    public function results(Request $request)
    {
        $this->authorizeReviewer($request);

        $query = ProjectReview::query()
            ->with(['project.unit', 'project.owner', 'reviewer'])
            ->latest('reviewed_at');

        if ($request->user()->role !== Role::ADMIN) {
            $query->where('stage', $request->user()->role);
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

        if ($project->current_reviewer_role !== $request->user()->role) {
            abort(403, '当前项目不属于你的审核阶段');
        }

        $data = $request->validate([
            'decision' => ['required', 'in:approve,return,reject,recommend,accept'],
            'score' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'comment' => ['nullable', 'string', 'max:3000'],
            'metadata' => ['nullable', 'array'],
        ]);

        $review = ProjectReview::create($data + [
            'project_id' => $project->id,
            'reviewer_id' => $request->user()->id,
            'stage' => $request->user()->role,
            'reviewed_at' => now(),
        ]);

        $project->update($this->nextProjectState($project, $data['decision']));

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
            $this->notifyRole($project, $project->current_reviewer_role, '收到待审项目', '项目“'.$project->title.'”已流转到你的审核阶段。');
        }

        return response()->json([
            'review' => $review,
            'project' => $project->refresh(),
        ], 201);
    }

    private function authorizeReviewer(Request $request): void
    {
        if (! in_array($request->user()->role, Role::reviewerRoles(), true)) {
            abort(403, '无权处理审核任务');
        }
    }

    private function notifyRole(Project $project, string $role, string $title, string $body): void
    {
        User::query()
            ->where('role', $role)
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

    private function nextProjectState(Project $project, string $decision): array
    {
        if ($decision === 'return') {
            return ['status' => Project::STATUS_RETURNED, 'current_reviewer_role' => null];
        }

        if ($decision === 'reject') {
            return ['status' => Project::STATUS_REJECTED, 'current_reviewer_role' => null];
        }

        $flow = [Role::COUNTY => Role::DEPARTMENT, Role::DEPARTMENT => Role::EXPERT, Role::EXPERT => Role::ADMIN];
        $nextRole = $flow[$project->current_reviewer_role] ?? null;

        return $nextRole
            ? ['status' => Project::STATUS_REVIEWING, 'current_reviewer_role' => $nextRole]
            : ['status' => Project::STATUS_APPROVED, 'current_reviewer_role' => null];
    }
}
