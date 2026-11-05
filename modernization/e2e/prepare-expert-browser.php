<?php

use App\Models\Project;
use App\Models\User;
use App\Support\ReviewDispatchMatcher;
use App\Support\ReviewScoreCriteria;
use Illuminate\Contracts\Console\Kernel;

$app = require __DIR__.'/isolated-app.php';
$app->make(Kernel::class)->bootstrap();
if (! $app->environment('testing') || config('database.default') !== 'sqlite') {
    throw new RuntimeException('Only the existing isolated SQLite sandbox is allowed.');
}
$sandbox = getenv('NXM_QA_SANDBOX');
$manifest = json_decode(file_get_contents($sandbox.'/credentials.json'), true, flags: JSON_THROW_ON_ERROR);
$owner = User::findOrFail($manifest['accounts']['unit']['id']);
if (! ($owner->metadata['e2e'] ?? false)) {
    throw new RuntimeException('An explicit synthetic owner is required.');
}
$receipt = $sandbox.'/qa105-project.json';
if (file_exists($receipt)) {
    throw new RuntimeException('Refusing to overwrite an existing test receipt.');
}
$criteria = ReviewScoreCriteria::active();
if (ReviewScoreCriteria::maxTotal($criteria) !== 100.0) {
    throw new RuntimeException('The isolated scoring template must total 100.');
}
$project = Project::create([
    'title' => 'QA105-EXPERT-BROWSER-'.gmdate('YmdHis'),
    'unit_id' => $owner->unit_id, 'owner_id' => $owner->id,
    'application_batch_id' => $manifest['batch_id'],
    'category' => 'QA Category', 'project_type' => 'QA Type',
    'summary' => '<p>QA105 synthetic submitted summary</p>',
    'budget_amount' => 100000, 'status' => Project::STATUS_REVIEWING,
    'current_reviewer_role' => 'expert', 'submitted_at' => now(),
    'metadata' => [
        'overview' => '<p>QA105 full research overview</p>',
        'objectives' => '<p>QA105 detailed research objectives</p>',
        'innovation' => '<p>QA105 innovation evidence</p>',
        'leader' => ['name' => 'Synthetic QA Leader'],
    ],
]);
$assignment = app(ReviewDispatchMatcher::class)->apply($project, 'expert');
$project->save();
$assigned = $assignment['assigned_user_ids'];
$expected = array_map(fn ($label) => $manifest['accounts'][$label]['id'], ['expert', 'expert_2', 'expert_3']);
sort($assigned);
sort($expected);
if ($assigned !== $expected) {
    throw new RuntimeException('Expected the three synthetic experts and no others.');
}
$output = ['id' => $project->id, 'title' => $project->title, 'criteria' => $criteria, 'assigned_count' => count($assigned)];
file_put_contents($receipt, json_encode($output, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
echo json_encode(['status' => 'ready', 'project_id' => $project->id, 'assigned_count' => count($assigned), 'production_changed' => false]).PHP_EOL;
