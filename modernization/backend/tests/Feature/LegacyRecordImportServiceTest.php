<?php

namespace Tests\Feature;

use App\Services\LegacyRecordImportService;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

class LegacyRecordImportServiceTest extends TestCase
{
    public function test_project_file_preview_blocks_invalid_storage_records(): void
    {
        $path = storage_path('framework/testing/legacy-project-files-preview.json');
        File::ensureDirectoryExists(dirname($path));
        File::put($path, json_encode([
            'summary' => ['total_records' => 3],
            'records' => [
                $this->projectFileRecord(['legacy_id' => 'valid']),
                $this->projectFileRecord(['legacy_id' => 'bad-disk', 'disk' => 'public']),
                $this->projectFileRecord(['legacy_id' => 'bad-path', 'path' => '../outside.pdf']),
            ],
        ], JSON_UNESCAPED_UNICODE));

        try {
            $preview = app(LegacyRecordImportService::class)->preview('project_files', $path);
        } finally {
            File::delete($path);
        }

        $this->assertSame('dry_run_ready', $preview['status']);
        $this->assertSame(3, $preview['plan_summary']['planned_records']);
        $this->assertSame(1, $preview['plan_summary']['ready_records']);
        $this->assertSame(2, $preview['plan_summary']['blocked_records']);
        $this->assertSame(1, $preview['plan_summary']['blocker_counts']['project_file.invalid_disk']);
        $this->assertSame(1, $preview['plan_summary']['blocker_counts']['project_file.invalid_path']);
        $this->assertSame(['project_file.invalid_disk'], $preview['planned_records'][1]['blockers']);
        $this->assertSame(['project_file.invalid_path'], $preview['planned_records'][2]['blockers']);
    }

    /** @param array<string, mixed> $overrides @return array<string, mixed> */
    private function projectFileRecord(array $overrides = []): array
    {
        return array_merge([
            'db_status' => 'ready_for_import',
            'legacy_id' => 'pro_file:1:fname',
            'project_id' => 100001,
            'uploaded_by' => null,
            'disk' => 'private',
            'path' => 'legacy/projects/83/pro_file-1-fname.pdf',
            'original_name' => '附件.pdf',
            'mime_type' => 'application/pdf',
            'extension' => 'pdf',
            'size_bytes' => 123,
            'sha256' => hash('sha256', 'legacy'),
            'purpose' => 'legacy_project_attachment',
            'metadata' => [],
            'warnings' => [],
        ], $overrides);
    }
}
