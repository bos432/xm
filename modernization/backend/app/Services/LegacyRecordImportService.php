<?php

namespace App\Services;

use App\Models\ProjectFile;
use App\Support\ProjectFileStorage;
use Illuminate\Support\Facades\File;

class LegacyRecordImportService
{
    /** @var array<string, string> */
    private array $defaultReports = [
        'units' => 'scripts/legacy-unit-user-db-dry-run.json',
        'users' => 'scripts/legacy-unit-user-db-dry-run.json',
        'projects' => 'scripts/legacy-project-db-dry-run.json',
        'project_files' => 'scripts/legacy-project-file-db-dry-run.json',
        'migration_batches' => 'scripts/legacy-migration-batch-db-dry-run.json',
    ];

    /** @var array<string, array<int, string>> */
    private array $fillableByTable = [
        'units' => [
            'legacy_id',
            'name',
            'credit_code',
            'contact_name',
            'contact_mobile',
            'email',
            'address',
            'region_code',
            'status',
            'metadata',
        ],
        'users' => [
            'name',
            'username',
            'email',
            'mobile',
            'password',
            'role',
            'unit_id',
            'is_active',
        ],
        'projects' => [
            'legacy_id',
            'unit_id',
            'owner_id',
            'title',
            'category',
            'project_type',
            'status',
            'summary',
            'budget_amount',
            'submitted_at',
            'current_reviewer_role',
            'metadata',
        ],
        'project_files' => [
            'legacy_id',
            'project_id',
            'uploaded_by',
            'disk',
            'path',
            'original_name',
            'mime_type',
            'extension',
            'size_bytes',
            'sha256',
            'purpose',
            'metadata',
        ],
        'migration_batches' => [
            'name',
            'mode',
            'source_path',
            'status',
            'started_at',
            'finished_at',
            'summary',
            'metadata',
        ],
        'migration_batch_items' => [
            'migration_batch_id',
            'legacy_table',
            'target_table',
            'status',
            'create_found',
            'insert_statement_count',
            'estimated_row_count',
            'warning_count',
            'metadata',
        ],
    ];

    /** @return array<string, string> */
    public function supportedTargets(): array
    {
        return $this->defaultReports;
    }

    /** @return array<string, mixed> */
    public function preview(string $target, ?string $reportPath = null): array
    {
        if (! array_key_exists($target, $this->defaultReports)) {
            return [
                'status' => 'unsupported_target',
                'target' => $target,
                'summary' => [],
            ];
        }

        $path = $reportPath ?: base_path('../'.$this->defaultReports[$target]);
        if (! File::exists($path)) {
            return [
                'status' => 'report_missing',
                'target' => $target,
                'report' => $path,
                'summary' => [],
            ];
        }

        $report = json_decode(File::get($path), true);
        if (! is_array($report)) {
            return [
                'status' => 'invalid_report',
                'target' => $target,
                'report' => $path,
                'summary' => [],
            ];
        }

        $plan = $this->buildPlan($target, $report);

        return [
            'status' => 'dry_run_ready',
            'target' => $target,
            'report' => $path,
            'summary' => $report['summary'] ?? [],
            'plan_summary' => $plan['summary'],
            'planned_records' => $plan['records'],
        ];
    }

    /** @return array<string, mixed> */
    public function import(string $target, ?string $reportPath = null): array
    {
        return [
            'status' => 'not_implemented',
            'target' => $target,
            'report' => $reportPath,
            'summary' => [],
        ];
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function buildPlan(string $target, array $report): array
    {
        return match ($target) {
            'units' => $this->planUnits($report),
            'users' => $this->planUsers($report),
            'projects' => $this->planProjects($report),
            'project_files' => $this->planProjectFiles($report),
            'migration_batches' => $this->planMigrationBatches($report),
            default => $this->emptyPlan($target, 'unsupported'),
        };
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function planUnits(array $report): array
    {
        return $this->planSingleTable('units', $this->recordsFromReport($report, 'units'));
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function planUsers(array $report): array
    {
        return $this->planSingleTable('users', $this->recordsFromReport($report, 'users'));
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function planProjects(array $report): array
    {
        return $this->planSingleTable('projects', $this->recordsFromReport($report, 'records'));
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function planProjectFiles(array $report): array
    {
        return $this->planSingleTable('project_files', $this->recordsFromReport($report, 'records'));
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function planMigrationBatches(array $report): array
    {
        $records = [];

        if (isset($report['batch']) && is_array($report['batch'])) {
            $records[] = $this->plannedRecord('migration_batches', $report['batch']);
        }

        foreach ($this->recordsFromReport($report, 'items') as $record) {
            $records[] = $this->plannedRecord('migration_batch_items', $record, [
                'migration_batch_name' => $report['batch']['name'] ?? null,
            ]);
        }

        return [
            'summary' => $this->summarizeRecords('migration_batches', $records, ['migration_batches', 'migration_batch_items']),
            'records' => $records,
        ];
    }

    /** @param array<int, array<string, mixed>> $records */
    private function planSingleTable(string $table, array $records): array
    {
        $planned = array_map(fn (array $record): array => $this->plannedRecord($table, $record), $records);

        return [
            'summary' => $this->summarizeRecords($table, $planned, [$table]),
            'records' => $planned,
        ];
    }

    /** @return array<int, array<string, mixed>> */
    private function recordsFromReport(array $report, string $key): array
    {
        if (isset($report[$key]) && is_array($report[$key])) {
            return $this->arrayRecords($report[$key]);
        }

        if (! isset($report['samples']) || ! is_array($report['samples'])) {
            return [];
        }

        if (isset($report['samples'][$key]) && is_array($report['samples'][$key])) {
            return $this->arrayRecords($report['samples'][$key]);
        }

        if ($key === 'records') {
            $records = [];
            foreach ($report['samples'] as $sampleGroup) {
                if (is_array($sampleGroup)) {
                    array_push($records, ...$this->arrayRecords($sampleGroup));
                }
            }

            return $records;
        }

        return [];
    }

    /** @return array<int, array<string, mixed>> */
    private function arrayRecords(array $records): array
    {
        return array_values(array_filter($records, fn ($record): bool => is_array($record)));
    }

    /** @param array<string, mixed> $references */
    private function plannedRecord(string $table, array $record, array $references = []): array
    {
        $status = (string) ($record['db_status'] ?? $record['status'] ?? 'unknown');
        $warnings = $this->stringList($record['warnings'] ?? []);
        $blockers = $this->inferBlockers($status, $warnings);
        $blockers = array_merge($blockers, $this->storageBlockers($table, $record));

        return [
            'action' => 'upsert',
            'target_table' => $table,
            'lookup' => $this->lookupFor($table, $record),
            'status' => $status,
            'is_ready' => $this->isReadyStatus($status) && count($blockers) === 0,
            'attributes' => $this->fillableAttributes($table, $record),
            'references' => array_filter($references, fn ($value): bool => $value !== null),
            'warnings' => $warnings,
            'blockers' => $blockers,
        ];
    }

    /** @param array<string, mixed> $record @return array<int, string> */
    private function storageBlockers(string $table, array $record): array
    {
        if ($table !== 'project_files') {
            return [];
        }

        $file = new ProjectFile([
            'project_id' => $record['project_id'] ?? null,
            'disk' => $record['disk'] ?? null,
            'path' => $record['path'] ?? null,
        ]);
        $blockers = [];

        if (! ProjectFileStorage::isAllowedDisk($file)) {
            $blockers[] = 'project_file.invalid_disk';
        }

        if (! ProjectFileStorage::isAllowedPath($file)) {
            $blockers[] = 'project_file.invalid_path';
        }

        return $blockers;
    }

    /** @return array<string, mixed> */
    private function fillableAttributes(string $table, array $record): array
    {
        $attributes = [];
        foreach ($this->fillableByTable[$table] ?? [] as $field) {
            if (array_key_exists($field, $record)) {
                $attributes[$field] = $record[$field];
            }
        }

        return $attributes;
    }

    /** @return array<string, mixed> */
    private function lookupFor(string $table, array $record): array
    {
        if (array_key_exists('legacy_id', $record) && $record['legacy_id'] !== null && $record['legacy_id'] !== '') {
            return ['legacy_id' => $record['legacy_id']];
        }

        if ($table === 'users' && ! empty($record['username'])) {
            return ['username' => $record['username']];
        }

        if ($table === 'migration_batches' && ! empty($record['name'])) {
            return ['name' => $record['name']];
        }

        if ($table === 'migration_batch_items') {
            return [
                'legacy_table' => $record['legacy_table'] ?? null,
                'target_table' => $record['target_table'] ?? null,
            ];
        }

        return [];
    }

    /** @return array<int, string> */
    private function stringList(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        return array_values(array_filter(array_map(
            fn ($item): string => is_scalar($item) ? (string) $item : '',
            $value,
        )));
    }

    /** @param array<int, string> $warnings @return array<int, string> */
    private function inferBlockers(string $status, array $warnings): array
    {
        $blockers = [];
        foreach ($warnings as $warning) {
            if ($warning === 'password_reset_required') {
                continue;
            }
            if (str_contains($warning, 'mapping_required') || str_contains($warning, 'missing') || str_contains($warning, 'blocked')) {
                $blockers[] = $warning;
            }
        }

        if (! $this->isReadyStatus($status)) {
            $blockers[] = 'status:'.$status;
        }

        return array_values(array_unique($blockers));
    }

    private function isReadyStatus(string $status): bool
    {
        return in_array($status, ['ready', 'ready_for_import'], true);
    }

    /** @param array<int, array<string, mixed>> $records @param array<int, string> $tables @return array<string, mixed> */
    private function summarizeRecords(string $target, array $records, array $tables): array
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
            'target' => $target,
            'mode' => 'dry_run',
            'target_tables' => $tables,
            'planned_records' => count($records),
            'ready_records' => $readyCount,
            'blocked_records' => $blockedCount,
            'waiting_records' => max(0, count($records) - $readyCount - $blockedCount),
            'status_counts' => $statusCounts,
            'blocker_counts' => $blockerCounts,
        ];
    }

    /** @return array{summary: array<string, mixed>, records: array<int, array<string, mixed>>} */
    private function emptyPlan(string $target, string $reason): array
    {
        return [
            'summary' => [
                'target' => $target,
                'mode' => 'dry_run',
                'target_tables' => [],
                'planned_records' => 0,
                'ready_records' => 0,
                'blocked_records' => 0,
                'waiting_records' => 0,
                'status_counts' => [],
                'blocker_counts' => ['reason:'.$reason => 1],
            ],
            'records' => [],
        ];
    }
}
