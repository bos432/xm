<?php

use App\Models\Project;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

$app = require __DIR__.'/isolated-app.php';
$app->make(Kernel::class)->bootstrap();
$project = Project::query()->where('title', 'QA-20261105-BROWSER-项目全流程')->firstOrFail();
$reviews = $project->reviews()->orderBy('id')->get();
echo json_encode([
    'driver' => DB::connection()->getDriverName(),
    'project_id' => $project->id,
    'status' => $project->status,
    'current_reviewer_role' => $project->current_reviewer_role,
    'budget_amount' => $project->budget_amount,
    'metadata_keys' => array_keys($project->metadata ?? []),
    'leader_present' => filled($project->metadata['leader']['name'] ?? null),
    'contact_present' => filled($project->metadata['contact']['name'] ?? null),
    'final_support' => $project->metadata['final_support'] ?? null,
    'reviews' => $reviews->map(fn ($review) => [
        'stage' => $review->stage,
        'reviewer_id' => $review->reviewer_id,
        'decision' => $review->decision,
        'score' => $review->score,
    ])->all(),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
