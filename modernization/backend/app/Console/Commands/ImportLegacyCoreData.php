<?php

namespace App\Console\Commands;

use App\Models\MigrationBatch;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class ImportLegacyCoreData extends Command
{
    protected $signature = 'legacy:import-core {dump : Path to the legacy SQL dump} {--dry-run : Parse and report only} {--record : Store dry-run results in migration_batches}';

    protected $description = 'Import or dry-run core legacy pro_ tables into the rebuilt schema.';

    private array $coreTables = [
        'pro_unit',
        'pro_manage',
        'pro_root',
        'pro_pro',
        'pro_file',
        'pro_review',
        'pro_check_log',
        'pro_log',
    ];

    private array $targetTables = [
        'pro_unit' => 'units',
        'pro_manage' => 'users',
        'pro_root' => 'users',
        'pro_pro' => 'projects',
        'pro_file' => 'project_files',
        'pro_review' => 'project_reviews',
        'pro_check_log' => 'project_reviews',
        'pro_log' => 'operation_logs',
    ];

    public function handle(): int
    {
        $dump = $this->argument('dump');
        if (! File::exists($dump)) {
            $this->error("SQL dump not found: {$dump}");
            return self::FAILURE;
        }

        $this->info('Legacy core import readiness');
        $this->line('Dump: '.$dump);
        $this->line('Mode: '.($this->option('dry-run') ? 'dry-run' : 'import'));

        $content = File::get($dump);
        $results = [];
        foreach ($this->coreTables as $table) {
            $results[] = $this->inspectTable($content, $table);
        }

        foreach ($results as $result) {
            $this->line(sprintf(
                '%-18s create=%s inserts=%d rows~=%d warnings=%d',
                $result['legacy_table'],
                $result['create_found'] ? 'yes' : 'no',
                $result['insert_statement_count'],
                $result['estimated_row_count'],
                $result['warning_count'],
            ));
        }

        if (! $this->option('dry-run')) {
            $this->warn('Write import is intentionally not enabled until field-level mapping is approved.');
            return self::FAILURE;
        }

        if ($this->option('record')) {
            $this->recordDryRun($dump, $results);
            $this->info('Dry-run batch recorded.');
        }

        return self::SUCCESS;
    }

    private function inspectTable(string $content, string $table): array
    {
        $insertPattern = '/INSERT INTO `'.preg_quote($table, '/').'`.*?;/s';
        preg_match_all($insertPattern, $content, $matches);

        $estimatedRows = 0;
        foreach ($matches[0] as $statement) {
            $estimatedRows += max(1, substr_count($statement, '),(') + substr_count($statement, "),\n(") + substr_count($statement, "),\r\n("));
        }

        $createFound = str_contains($content, "CREATE TABLE `{$table}`");
        $warnings = 0;
        if (! $createFound) {
            $warnings++;
        }
        if ($createFound && count($matches[0]) === 0) {
            $warnings++;
        }

        return [
            'legacy_table' => $table,
            'target_table' => $this->targetTables[$table] ?? null,
            'status' => $warnings > 0 ? 'warning' : 'ready',
            'create_found' => $createFound,
            'insert_statement_count' => count($matches[0]),
            'estimated_row_count' => $estimatedRows,
            'warning_count' => $warnings,
        ];
    }

    private function recordDryRun(string $dump, array $results): void
    {
        $batch = MigrationBatch::create([
            'name' => 'legacy-core-dry-run-'.now()->format('YmdHis'),
            'mode' => 'dry_run',
            'source_path' => $dump,
            'status' => 'completed',
            'started_at' => now(),
            'finished_at' => now(),
            'summary' => [
                'table_count' => count($results),
                'warning_count' => array_sum(array_column($results, 'warning_count')),
                'estimated_row_count' => array_sum(array_column($results, 'estimated_row_count')),
            ],
        ]);

        foreach ($results as $result) {
            $batch->items()->create($result);
        }
    }
}
