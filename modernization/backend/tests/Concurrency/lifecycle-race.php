<?php

use App\Models\ExpertCertification;
use App\Models\OperationLog;
use App\Models\Project;
use App\Models\ProjectProgressRecord;
use App\Models\ProjectRectification;
use App\Models\ProjectTaskBook;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Process\Process;

// This runner must never load a production connection or run against an existing business database.
if (getenv('APP_ENV') !== 'testing' || getenv('QA_EXPECTED_DB_DRIVER') !== 'mysql'
    || getenv('DB_CONNECTION') !== 'mysql' || getenv('DB_DATABASE') !== 'modernization_migration_test'
    || getenv('DB_HOST') !== '127.0.0.1') {
    fwrite(STDERR, "Refusing concurrency test outside explicit isolated MySQL testing database.\n");
    exit(2);
}

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(ConsoleKernel::class)->bootstrap();
if (! $app->environment('testing') || DB::connection()->getDriverName() !== 'mysql'
    || DB::connection()->getDatabaseName() !== 'modernization_migration_test') {
    throw new RuntimeException('Resolved database/environment differs from isolated test contract');
}

if (($argv[1] ?? '') === 'worker') {
    $input = json_decode(stream_get_contents(STDIN), true, flags: JSON_THROW_ON_ERROR);
    $entered = false;
    $input['model']::retrieved(function ($record) use ($input, &$entered): void {
        if ($entered || (int) $record->id !== $input['record_id']) {
            return;
        }
        $entered = true;
        file_put_contents($input['barrier'].'/ready-'.$input['slot'], json_encode([
            'pid' => getmypid(), 'status' => $record->status, 'id' => $record->id,
        ], JSON_THROW_ON_ERROR));
        $deadline = microtime(true) + 12;
        while (! is_file($input['barrier'].'/release')) {
            if (microtime(true) > $deadline) {
                throw new RuntimeException('Worker barrier timed out');
            }
            usleep(10000);
            clearstatcache();
        }
    });
    $request = Request::create($input['url'], 'POST', server: [
        'HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json',
        'HTTP_AUTHORIZATION' => 'Bearer '.$input['token'], 'REMOTE_ADDR' => '127.0.0.1',
    ], content: json_encode($input['payload'], JSON_THROW_ON_ERROR));
    $kernel = $app->make(HttpKernel::class);
    $response = $kernel->handle($request);
    $kernel->terminate($request, $response);
    echo json_encode(['status' => $response->getStatusCode(), 'pid' => getmypid()], JSON_THROW_ON_ERROR)."\n";
    exit(0);
}

$results = [];
$failed = false;
$cases = [
    'task_book' => [ProjectTaskBook::class, 'task-books', 'task_book.reviewed'],
    'progress' => [ProjectProgressRecord::class, 'progress', 'project_progress.reviewed'],
    'rectification' => [ProjectRectification::class, 'rectifications', 'rectification.reviewed'],
    'certification' => [ExpertCertification::class, 'expert-certifications', 'expert_certification.reviewed'],
    'project' => [Project::class, null, 'project.reviewed'],
];
foreach ($cases as $kind => [$model, $route, $auditAction]) {
    $unit = Unit::factory()->create();
    $owner = User::factory()->create(['role' => 'unit', 'unit_id' => $unit->id]);
    $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id,
        'status' => $kind === 'project' ? 'submitted' : 'approved',
        'current_reviewer_role' => $kind === 'project' ? 'county' : null]);
    $reviewers = [User::factory()->create(['role' => $kind === 'project' ? 'county' : 'admin']),
        User::factory()->create(['role' => $kind === 'project' ? 'county' : 'admin'])];
    $base = ['project_id' => $project->id, 'unit_id' => $unit->id, 'status' => 'submitted', 'submitted_by' => $owner->id];
    $record = match ($kind) {
        'task_book' => ProjectTaskBook::create($base + ['title' => 'QA concurrent task']),
        'progress' => ProjectProgressRecord::create($base + ['summary' => 'QA concurrent progress']),
        'rectification' => ProjectRectification::create($base + ['title' => 'QA concurrent rectification', 'created_by' => $reviewers[0]->id]),
        'certification' => ExpertCertification::create(['user_id' => User::factory()->create(['role' => 'expert'])->id,
            'submitted_by' => $owner->id, 'status' => 'submitted', 'specialty' => 'QA concurrency']),
        'project' => $project,
    };
    $barrier = sys_get_temp_dir().'/nxm-race-'.bin2hex(random_bytes(8));
    mkdir($barrier, 0700);
    $workers = [];
    $tokens = [];
    try {
        foreach ($reviewers as $slot => $reviewer) {
            $token = $reviewer->createToken('isolated-concurrency');
            $tokens[] = $token->accessToken;
            $worker = new Process([PHP_BINARY, __FILE__, 'worker'], dirname(__DIR__, 2));
            $worker->setTimeout(25);
            $worker->setInput(json_encode([
                'slot' => $slot, 'model' => $model, 'record_id' => $record->id, 'barrier' => $barrier,
                'token' => $token->plainTextToken,
                'url' => $kind === 'project' ? '/api/projects/'.$project->id.'/reviews' : '/api/lifecycle/'.$route.'/'.$record->id.'/review',
                'payload' => ['decision' => $slot === 0 ? 'approve' : 'reject', 'comment' => 'QA race slot '.$slot],
            ], JSON_THROW_ON_ERROR));
            $worker->start();
            $workers[] = $worker;
        }
        $deadline = microtime(true) + 15;
        while (! is_file($barrier.'/ready-0') || ! is_file($barrier.'/ready-1')) {
            foreach ($workers as $worker) {
                if (! $worker->isRunning()) {
                    throw new RuntimeException('Worker exited before barrier: '.$worker->getErrorOutput());
                }
            }
            if (microtime(true) > $deadline) {
                throw new RuntimeException('Parent barrier timed out');
            }
            usleep(10000);
            clearstatcache();
        }
        $ready = [json_decode(file_get_contents($barrier.'/ready-0'), true, flags: JSON_THROW_ON_ERROR),
            json_decode(file_get_contents($barrier.'/ready-1'), true, flags: JSON_THROW_ON_ERROR)];
        file_put_contents($barrier.'/release', 'go');
        $responses = [];
        foreach ($workers as $slot => $worker) {
            $worker->wait();
            if (! $worker->isSuccessful()) {
                throw new RuntimeException('Worker failed: '.$worker->getErrorOutput());
            }
            $responses[$slot] = json_decode(trim($worker->getOutput()), true, flags: JSON_THROW_ON_ERROR);
        }
        $statuses = array_column($responses, 'status');
        sort($statuses);
        $expected = $kind === 'project' ? [201, 409] : [200, 422];
        $winner = array_search($kind === 'project' ? 201 : 200, array_column($responses, 'status'), true);
        $record->refresh();
        $auditCount = OperationLog::query()->where('action', $auditAction)
            ->where('payload->project_id', $project->id)->count();
        if ($kind === 'certification') {
            $auditCount = OperationLog::query()->where('action', $auditAction)->where('target_id', $record->id)->count();
        }
        $preserved = $kind === 'project'
            ? $project->reviews()->count() === 1
            : ($winner !== false && $record->reviewed_by === $reviewers[$winner]->id && $record->review_comment === 'QA race slot '.$winner);
        $passed = $statuses === $expected && $preserved && $auditCount === 1 && $ready[0]['pid'] !== $ready[1]['pid'];
        $results[] = ['kind' => $kind, 'statuses' => $statuses, 'expected' => $expected,
            'worker_reads' => $ready, 'final_status' => $record->status, 'single_audit' => $auditCount === 1,
            'winner_preserved' => $preserved, 'passed' => $passed];
        $failed = $failed || ! $passed;
    } finally {
        foreach ($workers as $worker) {
            if ($worker->isRunning()) {
                $worker->stop(1);
            }
        }
        foreach ($tokens as $token) {
            $token->delete();
        }
        foreach (['ready-0', 'ready-1', 'release'] as $file) {
            if (is_file($barrier.'/'.$file)) {
                unlink($barrier.'/'.$file);
            }
        }
        rmdir($barrier);
    }
}
echo json_encode(['driver' => DB::connection()->getDriverName(), 'mysql' => DB::selectOne('select version() as version')->version,
    'environment' => $app->environment(), 'results' => $results], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)."\n";
exit($failed ? 1 : 0);
