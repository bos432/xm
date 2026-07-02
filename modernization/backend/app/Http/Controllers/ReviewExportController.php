<?php

namespace App\Http\Controllers;

use App\Models\Project;
use App\Models\ProjectReview;
use App\Support\AuditLogger;
use App\Support\CsvExport;
use App\Support\Role;
use App\Support\ReviewDispatchMatcher;
use App\Support\ReviewScoreCriteria;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReviewExportController extends Controller
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly ReviewDispatchMatcher $dispatchMatcher,
    )
    {
    }

    public function tasksCsv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'review_projects')) {
            abort(403, '无权导出审核任务');
        }

        $projects = Project::query()
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
            ->orderByDesc('id')
            ->get()
            ->filter(fn (Project $project): bool => $this->dispatchMatcher->userCanReview(
                $project,
                $request->user(),
                Role::reviewerStageFor($request->user()->role)
            ))
            ->values();

        $this->auditLogger->record($request, 'review_tasks.exported', null, [
            'format' => 'csv',
            'reviewer_role' => $request->user()->role,
            'project_id' => $request->query('project_id'),
            'category' => $request->query('category'),
            'project_type' => $request->query('project_type'),
            'keyword' => $request->query('keyword'),
            'count' => $projects->count(),
        ]);

        $filename = 'review-tasks-'.$request->user()->role.'-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($projects): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            CsvExport::writeRow($output, ['项目ID', '项目名称', '申报单位', '项目类别', '项目类型', '状态', '当前审核阶段', '预算金额（元）', '提交时间', '负责人账号']);

            foreach ($projects as $project) {
                CsvExport::writeRow($output, [
                    $project->id,
                    $project->title,
                    $project->unit?->name,
                    $project->category,
                    $project->project_type,
                    $project->status,
                    $project->current_reviewer_role,
                    $project->budget_amount,
                    optional($project->submitted_at)->format('Y-m-d H:i:s'),
                    $project->owner?->username,
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function resultsCsv(Request $request): StreamedResponse
    {
        if (! Role::userCan($request->user(), 'review_projects')) {
            abort(403, '无权导出审核结果');
        }

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

        $reviews = $query->get();

        $this->auditLogger->record($request, 'review_results.exported', null, [
            'format' => 'csv',
            'stage' => in_array($request->user()->role, Role::adminRoles(), true) ? $request->query('stage') : Role::reviewerStageFor($request->user()->role),
            'project_id' => $request->query('project_id'),
            'decision' => $request->query('decision'),
            'score_min' => $request->query('score_min'),
            'score_max' => $request->query('score_max'),
            'category' => $request->query('category'),
            'project_type' => $request->query('project_type'),
            'keyword' => $request->query('keyword'),
            'count' => $reviews->count(),
        ]);

        $filename = 'review-results-'.now()->format('Ymd-His').'.csv';
        $criteria = ReviewScoreCriteria::active();

        return response()->streamDownload(function () use ($reviews, $criteria): void {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            $criterionHeaders = array_map(
                fn (array $item): string => $item['label'].'（'.$item['max_score'].'分）',
                $criteria
            );
            CsvExport::writeRow($output, [
                '审核ID',
                '项目ID',
                '项目名称',
                '申报单位',
                '项目类别',
                '项目类型',
                '审核阶段',
                '审核结果',
                '评分',
                ...$criterionHeaders,
                '审核意见',
                '审核人账号',
                '审核时间',
                '项目状态',
            ]);

            foreach ($reviews as $review) {
                $scoreMap = ReviewScoreCriteria::scoreMapFromReviewMetadata($review->metadata);
                CsvExport::writeRow($output, [
                    $review->id,
                    $review->project_id,
                    $review->project?->title,
                    $review->project?->unit?->name,
                    $review->project?->category,
                    $review->project?->project_type,
                    $review->stage,
                    $review->decision,
                    $review->score,
                    ...array_map(fn (array $item): mixed => $scoreMap[$item['code']] ?? '', $criteria),
                    $review->comment,
                    $review->reviewer?->username,
                    optional($review->reviewed_at)->format('Y-m-d H:i:s'),
                    $review->project?->status,
                ]);
            }

            fclose($output);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
