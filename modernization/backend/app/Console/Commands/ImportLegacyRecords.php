<?php

namespace App\Console\Commands;

use App\Services\LegacyRecordImportService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class ImportLegacyRecords extends Command
{
    protected $signature = 'legacy:import-records
        {target : units|users|projects|project_files|migration_batches|all}
        {--report= : Override the report path}
        {--output= : Write the dry-run preview JSON to this path}
        {--execute : Reserved for the future real import path}
        {--confirm-production-import : Required with --execute once real imports are implemented}';

    protected $description = 'Preview legacy migration records for future database import. Defaults to dry-run and does not write data.';

    public function handle(LegacyRecordImportService $imports): int
    {
        if ($this->option('execute')) {
            $this->error('Real database imports are not implemented yet. Run without --execute to preview records.');

            return self::FAILURE;
        }

        $target = (string) $this->argument('target');
        if ($target === 'all') {
            $results = [];
            $exitCode = self::SUCCESS;

            foreach (array_keys($imports->supportedTargets()) as $item) {
                $result = $imports->preview($item, $this->option('report'));
                $results[$item] = $result;
                if ($this->printPreviewResult($item, $result) === self::FAILURE) {
                    $exitCode = self::FAILURE;
                }
            }

            if ($exitCode === self::SUCCESS) {
                $this->writeOutputIfRequested($this->allTargetsOutput($results));
            }

            return $exitCode;
        }

        if (! array_key_exists($target, $imports->supportedTargets())) {
            $this->error('Unsupported target: '.$target);

            return self::FAILURE;
        }

        $result = $imports->preview($target, $this->option('report'));
        $exitCode = $this->printPreviewResult($target, $result);
        if ($exitCode === self::SUCCESS) {
            $this->writeOutputIfRequested($result);
        }

        return $exitCode;
    }

    /** @param array<string, mixed> $result */
    private function printPreviewResult(string $target, array $result): int
    {
        if ($result['status'] === 'report_missing') {
            $this->warn("Report missing for {$target}: {$result['report']}");

            return self::SUCCESS;
        }
        if ($result['status'] === 'invalid_report') {
            $this->error("Invalid JSON report for {$target}: {$result['report']}");

            return self::FAILURE;
        }

        $this->info("[dry-run] {$target}");
        $this->line('report: '.$result['report']);
        $this->printScalarMap('source summary', $result['summary'] ?? []);
        $this->printScalarMap('plan summary', $result['plan_summary'] ?? []);
        $this->printNestedCounts('status counts', $result['plan_summary']['status_counts'] ?? []);
        $this->printNestedCounts('blocker counts', $result['plan_summary']['blocker_counts'] ?? []);
        $this->line('sample planned records: '.count($result['planned_records'] ?? []));

        return self::SUCCESS;
    }

    /** @param array<string, mixed> $payload */
    private function writeOutputIfRequested(array $payload): void
    {
        $path = $this->option('output');
        if (! is_string($path) || $path === '') {
            return;
        }

        File::ensureDirectoryExists(dirname($path));
        File::put($path, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
        $this->info('dry-run JSON written to '.$path);
    }

    /** @param array<string, array<string, mixed>> $results @return array<string, mixed> */
    private function allTargetsOutput(array $results): array
    {
        $records = [];
        $targets = [];
        foreach ($results as $target => $result) {
            $plannedRecords = $result['planned_records'] ?? [];
            $plannedRecords = is_array($plannedRecords) ? $plannedRecords : [];
            array_push($records, ...$plannedRecords);
            $targets[] = [
                'target' => $target,
                'source_report' => $result['summary']['generated_at'] ?? null,
                'summary' => $result['plan_summary'] ?? $this->emptySummary($target, []),
                'sample_records' => array_slice($plannedRecords, 0, 20),
            ];
        }

        return [
            'generated_at' => now()->toIso8601String(),
            'mode' => 'dry_run',
            'note' => 'This report is an import plan preview only. It does not copy files, connect to MySQL, or write application tables.',
            'summary' => $this->summarizeAllTargets($records),
            'targets' => $targets,
        ];
    }

    /** @param array<int, array<string, mixed>> $records @return array<string, mixed> */
    private function summarizeAllTargets(array $records): array
    {
        $statusCounts = [];
        $blockerCounts = [];
        $readyCount = 0;
        $blockedCount = 0;

        foreach ($records as $record) {
            $status = (string) ($record['status'] ?? 'unknown');
            $statusCounts[$status] = ($statusCounts[$status] ?? 0) + 1;

            if (($record['is_ready'] ?? false) === true) {
                $readyCount++;
            }

            $blockers = $record['blockers'] ?? [];
            if (is_array($blockers) && count($blockers) > 0) {
                $blockedCount++;
                foreach ($blockers as $blocker) {
                    if (! is_scalar($blocker)) {
                        continue;
                    }
                    $key = (string) $blocker;
                    $blockerCounts[$key] = ($blockerCounts[$key] ?? 0) + 1;
                }
            }
        }

        ksort($statusCounts);
        ksort($blockerCounts);

        return [
            'target' => 'all',
            'mode' => 'dry_run',
            'target_tables' => ['units', 'users', 'projects', 'project_files', 'migration_batches', 'migration_batch_items'],
            'planned_records' => count($records),
            'ready_records' => $readyCount,
            'blocked_records' => $blockedCount,
            'waiting_records' => max(0, count($records) - $readyCount - $blockedCount),
            'status_counts' => $statusCounts,
            'blocker_counts' => $blockerCounts,
        ];
    }

    /** @param array<int, string> $tables @return array<string, mixed> */
    private function emptySummary(string $target, array $tables): array
    {
        return [
            'target' => $target,
            'mode' => 'dry_run',
            'target_tables' => $tables,
            'planned_records' => 0,
            'ready_records' => 0,
            'blocked_records' => 0,
            'waiting_records' => 0,
            'status_counts' => [],
            'blocker_counts' => [],
        ];
    }

    /** @param array<string, mixed> $values */
    private function printScalarMap(string $title, array $values): void
    {
        $printedTitle = false;
        foreach ($values as $key => $value) {
            if (! (is_scalar($value) || $value === null)) {
                continue;
            }

            if (! $printedTitle) {
                $this->line($title.':');
                $printedTitle = true;
            }

            $this->line('  '.$key.': '.($value ?? 'null'));
        }
    }

    /** @param array<string, mixed> $counts */
    private function printNestedCounts(string $title, array $counts): void
    {
        if ($counts === []) {
            return;
        }

        $this->line($title.':');
        foreach ($counts as $key => $value) {
            if (is_scalar($value) || $value === null) {
                $this->line('  '.$key.': '.($value ?? 'null'));
            }
        }
    }
}
