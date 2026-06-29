<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\MigrationBatch;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\ApplicationBatch;
use App\Models\AcceptanceExtension;
use App\Models\SecurityEvent;
use App\Models\SecurityLock;
use App\Models\Unit;
use App\Models\User;
use App\Support\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;

class DashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        if (! Role::userCan($request->user(), 'view_dashboard')) {
            abort(403, '无权查看运行概览');
        }

        $projectQuery = Project::query();
        if ($request->user()->role === Role::UNIT) {
            $projectQuery->where('unit_id', $request->user()->unit_id);
        }

        $projectsByStatus = (clone $projectQuery)
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $summary = [
            'projects' => [
                'total' => (clone $projectQuery)->count(),
                'by_status' => $projectsByStatus,
                'submitted_or_reviewing' => (clone $projectQuery)
                    ->whereIn('status', [Project::STATUS_SUBMITTED, Project::STATUS_REVIEWING])
                    ->count(),
            ],
            'reviews' => [
                'pending' => in_array($request->user()->role, Role::reviewerRoles(), true)
                    ? Project::query()
                        ->where('current_reviewer_role', Role::reviewerStageFor($request->user()->role))
                        ->whereIn('status', [Project::STATUS_SUBMITTED, Project::STATUS_REVIEWING])
                        ->count()
                    : 0,
            ],
            'messages' => [
                'unread' => Message::query()
                    ->where('recipient_id', $request->user()->id)
                    ->whereNull('read_at')
                    ->count(),
            ],
            'acceptance' => [
                'pending_extensions' => 0,
            ],
            'batches' => [
                'open' => ApplicationBatch::query()
                    ->where('status', ApplicationBatch::STATUS_OPEN)
                    ->where(function ($query): void {
                        $query->whereNull('starts_at')->orWhere('starts_at', '<=', now());
                    })
                    ->where(function ($query): void {
                        $query->whereNull('ends_at')->orWhere('ends_at', '>=', now());
                    })
                    ->count(),
                'current' => ApplicationBatch::query()
                    ->where('status', ApplicationBatch::STATUS_OPEN)
                    ->orderByDesc('starts_at')
                    ->first(),
            ],
            'registrations' => null,
            'operation_logs' => [
                'recent' => OperationLog::query()
                    ->with('user:id,name,username,role')
                    ->latest()
                    ->limit(6)
                    ->get(),
            ],
            'security' => null,
            'migration' => null,
        ];

        if (in_array($request->user()->role, Role::adminRoles(), true)) {
            $summary['acceptance']['pending_extensions'] = AcceptanceExtension::query()
                ->where('status', 'pending')
                ->count()
                + Project::query()
                    ->get()
                    ->sum(fn (Project $project) => collect($project->metadata['extension_requests'] ?? [])
                        ->filter(fn (array $item) => ($item['status'] ?? 'pending') === 'pending')
                        ->count());

            $summary['registrations'] = [
                'pending_units' => Unit::query()
                    ->where('status', 'suspended')
                    ->where(function ($query) {
                        $query->where('metadata', 'like', '%"registration_status":"pending"%')
                            ->orWhere('metadata', 'like', '%"registration_status": "pending"%');
                    })
                    ->count(),
                'pending_users' => User::query()
                    ->where('role', Role::UNIT)
                    ->where('is_active', false)
                    ->whereHas('unit', function ($query) {
                        $query->where('status', 'suspended')
                            ->where(function ($query) {
                                $query->where('metadata', 'like', '%"registration_status":"pending"%')
                                    ->orWhere('metadata', 'like', '%"registration_status": "pending"%');
                            });
                    })
                    ->count(),
            ];

            $summary['security'] = [
                'security_events_24h' => SecurityEvent::query()
                    ->where('created_at', '>=', now()->subDay())
                    ->count(),
                'active_locks' => SecurityLock::query()
                    ->where('is_active', true)
                    ->where(function ($query): void {
                        $query->whereNull('locked_until')->orWhere('locked_until', '>', now());
                    })
                    ->count(),
                'recent_security_events' => SecurityEvent::query()
                    ->with('user:id,name,username,role')
                    ->latest()
                    ->limit(5)
                    ->get(),
            ];

            $summary['migration'] = [
                'latest_batch' => MigrationBatch::query()->latest()->first(),
                'preflight' => $this->readJsonReport('legacy-migration-preflight-checklist.json'),
                'go_live_gate' => $this->readJsonReport('legacy-migration-go-live-gate.json'),
            ];
        }

        return response()->json($summary);
    }

    private function readJsonReport(string $filename): ?array
    {
        $path = base_path('../scripts/'.$filename);

        if (! File::exists($path)) {
            return null;
        }

        return json_decode(File::get($path), true);
    }
}
