<?php

use App\Models\AcceptanceApplication;
use App\Models\AcceptanceExtension;
use App\Models\DictionaryItem;
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

DictionaryItem::query()->where('group', 'expert_review_criterion')
    ->where('code', 'like', 'qa_race_%')->update(['is_active' => false]);

$results = [];
$failed = false;
$qaUser = static function (array $attributes): User {
    $suffix = bin2hex(random_bytes(12));

    return User::factory()->create($attributes + [
        'username' => 'qa_race_'.$suffix,
        'email' => 'qa_race_'.$suffix.'@example.invalid',
        'mobile' => '1'.str_pad((string) random_int(0, 9999999999), 10, '0', STR_PAD_LEFT),
    ]);
};
$cases = [
    'task_book' => [ProjectTaskBook::class, 'task-books', 'task_book.reviewed'],
    'progress' => [ProjectProgressRecord::class, 'progress', 'project_progress.reviewed'],
    'rectification' => [ProjectRectification::class, 'rectifications', 'rectification.reviewed'],
    'certification' => [ExpertCertification::class, 'expert-certifications', 'expert_certification.reviewed'],
    'acceptance' => [AcceptanceApplication::class, null, 'acceptance.reviewed'],
    'acceptance_extension' => [AcceptanceExtension::class, null, 'acceptance.extension_reviewed'],
    'expert_project_reviews' => [Project::class, null, 'project.reviewed'],
    'project' => [Project::class, null, 'project.reviewed'],
];
foreach ($cases as $kind => [$model, $route, $auditAction]) {
    $unit = Unit::factory()->create();
    $owner = $qaUser(['role' => 'unit', 'unit_id' => $unit->id]);
    $reviewRole = match ($kind) {
        'project', 'acceptance' => 'county',
        'expert_project_reviews' => 'expert',
        default => 'admin',
    };
    $stage = match ($kind) {
        'project', 'acceptance' => 'county',
        'expert_project_reviews' => 'expert',
        default => null,
    };
    $project = Project::factory()->create(['unit_id' => $unit->id, 'owner_id' => $owner->id,
        'status' => $kind === 'project' ? 'submitted' : (in_array($kind, ['acceptance', 'expert_project_reviews'], true)
            ? ($kind === 'acceptance' ? 'acceptance' : 'reviewing') : 'approved'),
        'current_reviewer_role' => $stage]);
    $reviewers = [$qaUser(['role' => $reviewRole]), $qaUser(['role' => $reviewRole])];
    $criterionCodes = [];
    if ($kind === 'expert_project_reviews') {
        foreach (range(1, 4) as $index) {
            $criterionCode = 'qa_race_'.$index.'_'.bin2hex(random_bytes(4));
            $criterionCodes[] = $criterionCode;
            DictionaryItem::create([
                'group' => 'expert_review_criterion', 'code' => $criterionCode,
                'label' => 'QA criterion '.$index, 'sort_order' => $index, 'is_active' => true,
                'metadata' => ['max_score' => 25],
            ]);
        }
        $project->update(['metadata' => ['review_dispatch' => ['assignments' => ['expert' => [
            'stage' => 'expert', 'auto_assign' => true, 'assigned_user_ids' => collect($reviewers)->pluck('id')->all(),
        ]]]]]);
    }
    $base = ['project_id' => $project->id, 'unit_id' => $unit->id, 'status' => 'submitted', 'submitted_by' => $owner->id];
    $record = match ($kind) {
        'task_book' => ProjectTaskBook::create($base + ['title' => 'QA concurrent task']),
        'progress' => ProjectProgressRecord::create($base + ['summary' => 'QA concurrent progress']),
        'rectification' => ProjectRectification::create($base + ['title' => 'QA concurrent rectification', 'created_by' => $reviewers[0]->id]),
        'certification' => ExpertCertification::create(['user_id' => $qaUser(['role' => 'expert'])->id,
            'submitted_by' => $owner->id, 'status' => 'submitted', 'specialty' => 'QA concurrency']),
        'acceptance' => AcceptanceApplication::create(['project_id' => $project->id, 'unit_id' => $unit->id,
            'submitted_by' => $owner->id, 'status' => 'submitted', 'current_reviewer_role' => 'county']),
        'acceptance_extension' => AcceptanceExtension::create(['project_id' => $project->id, 'requested_by' => $owner->id,
            'status' => 'pending', 'reason' => 'QA concurrency extension']),
        'expert_project_reviews' => $project,
        'project' => $project,
    };
    if ($kind === 'acceptance_extension') {
        $acceptance = AcceptanceApplication::create(['project_id' => $project->id, 'unit_id' => $unit->id,
            'submitted_by' => $owner->id, 'status' => 'submitted', 'current_reviewer_role' => 'county']);
        $record->update(['acceptance_application_id' => $acceptance->id]);
    }
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
                'url' => match ($kind) {
                    'project', 'expert_project_reviews' => '/api/projects/'.$project->id.'/reviews',
                    'acceptance' => '/api/acceptance/'.$record->id.'/reviews',
                    'acceptance_extension' => '/api/acceptance/'.$project->acceptanceApplications()->first()->id.'/extensions',
                    default => '/api/lifecycle/'.$route.'/'.$record->id.'/review',
                },
                'payload' => match ($kind) {
                    'acceptance_extension' => ['extension_id' => $record->id, 'decision' => $slot === 0 ? 'approved' : 'rejected', 'comment' => 'QA race slot '.$slot],
                    'expert_project_reviews' => ['decision' => 'recommend', 'metadata' => ['score_criteria' => $slot === 0
                        ? array_combine($criterionCodes, [25, 25, 20, 20])
                        : array_combine($criterionCodes, [20, 20, 20, 20])]],
                    default => ['decision' => $slot === 0 ? 'approve' : 'reject', 'comment' => 'QA race slot '.$slot],
                },
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
        $expected = $kind === 'project' ? [201, 409] : ($kind === 'expert_project_reviews' ? [201, 201]
            : (in_array($kind, ['acceptance', 'acceptance_extension'], true)
                ? ($kind === 'acceptance' ? [201, 422] : [200, 422]) : [200, 422]));
        $successStatus = in_array($kind, ['project', 'acceptance', 'expert_project_reviews'], true) ? 201 : 200;
        $winner = array_search($successStatus, array_column($responses, 'status'), true);
        $record->refresh();
        $auditCount = OperationLog::query()->where('action', $auditAction)->where('payload->project_id', $project->id)->count();
        if ($kind === 'acceptance') {
            $auditCount = OperationLog::query()->where('action', $auditAction)
                ->where('payload->acceptance_id', $record->id)->count();
        } elseif ($kind === 'acceptance_extension') {
            $auditCount = OperationLog::query()->where('action', $auditAction)->where('target_id', $record->id)->count();
        } elseif ($kind === 'certification') {
            $auditCount = OperationLog::query()->where('action', $auditAction)->where('target_id', $record->id)->count();
        }
        $preserved = $kind === 'project'
            ? $project->reviews()->count() === 1
            : ($kind === 'expert_project_reviews'
                ? $project->reviews()->where('stage', 'expert')->count() === 2
                    && $project->fresh()->current_reviewer_role === 'admin'
                    && $project->reviews()->where('stage', 'expert')->pluck('reviewer_id')->sort()->values()->all()
                        === collect($reviewers)->pluck('id')->sort()->values()->all()
                    && $project->reviews()->where('reviewer_id', $reviewers[0]->id)->value('score') == 90
                    && $project->reviews()->where('reviewer_id', $reviewers[1]->id)->value('score') == 80
                : ($kind === 'acceptance'
                ? $record->reviews()->count() === 1 && $winner !== false && $record->reviews()->first()->reviewer_id === $reviewers[$winner]->id
                : ($winner !== false && $record->reviewed_by === $reviewers[$winner]->id
                    && $record->review_comment === 'QA race slot '.$winner)));
        $expectedAudits = $kind === 'expert_project_reviews' ? 2 : 1;
        $auditCountMatches = $auditCount === $expectedAudits;
        $passed = $statuses === $expected && $preserved && $auditCountMatches && $ready[0]['pid'] !== $ready[1]['pid'];
        $results[] = ['kind' => $kind, 'statuses' => $statuses, 'expected' => $expected,
            'worker_reads' => $ready, 'final_status' => $record->status,
            'audit_count' => $auditCount, 'expected_audit_count' => $expectedAudits,
            'audit_count_matches' => $auditCountMatches, 'winner_preserved' => $preserved, 'passed' => $passed];
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
