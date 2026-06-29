<?php

namespace App\Console\Commands;

use App\Models\PublicHomeItem;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ImportLegacyPublicHome extends Command
{
    protected $signature = 'legacy:import-public-home
        {dump : Path to the legacy SQL dump}
        {--upload-root=../../upload : Path to the legacy upload directory}
        {--execute : Write records and copy available files}';

    protected $description = 'Import or dry-run legacy pro_cms portal content for the public homepage.';

    public function handle(): int
    {
        $dump = $this->argument('dump');
        if (! File::exists($dump)) {
            $this->error("SQL dump not found: {$dump}");

            return self::FAILURE;
        }

        $records = $this->parseCmsRecords(File::get($dump));
        $summary = $this->summarize($records);
        $this->line('Mode: '.($this->option('execute') ? 'execute' : 'dry-run'));
        $this->line('pro_cms rows: '.count($records));
        $this->line('notices: '.$summary['notices']);
        $this->line('downloads: '.$summary['downloads']);
        $this->line('skipped: '.$summary['skipped']);

        if (! $this->option('execute')) {
            return self::SUCCESS;
        }

        $uploadRoot = $this->uploadRoot();
        $imported = ['notices' => 0, 'downloads' => 0, 'missing_files' => 0, 'skipped' => $summary['skipped']];
        foreach ($records as $record) {
            if ($record['kind'] === 1) {
                $this->importNotice($record);
                $imported['notices']++;
                continue;
            }

            if ($record['kind'] === 3) {
                $result = $this->importDownload($record, $uploadRoot);
                $imported['downloads']++;
                if ($result === 'missing_file') {
                    $imported['missing_files']++;
                }
            }
        }

        $this->line('imported notices: '.$imported['notices']);
        $this->line('imported downloads: '.$imported['downloads']);
        $this->line('missing download files: '.$imported['missing_files']);

        return self::SUCCESS;
    }

    private function uploadRoot(): string
    {
        $root = (string) $this->option('upload-root');
        if (str_starts_with($root, '/') || preg_match('/^[A-Za-z]:[\/\\\\]/', $root) === 1) {
            return $root;
        }

        return base_path($root);
    }

    private function importNotice(array $record): void
    {
        PublicHomeItem::updateOrCreate(
            ['legacy_source' => 'pro_cms', 'legacy_id' => $record['id']],
            [
                'section' => 'notice',
                'title' => $record['title'],
                'summary' => $this->summaryFromContent($record['content']),
                'body' => $record['content'],
                'published_at' => $record['time'],
                'sort_order' => 1000 + $record['id'],
                'is_active' => true,
                'metadata' => ['legacy_kind' => $record['kind']],
            ]
        );
    }

    private function importDownload(array $record, string $uploadRoot): string
    {
        $sourceName = basename((string) $record['content']);
        $sourcePath = rtrim($uploadRoot, '/\\').DIRECTORY_SEPARATOR.$sourceName;
        $extension = strtolower(pathinfo($sourceName, PATHINFO_EXTENSION));
        $metadata = ['legacy_kind' => $record['kind'], 'legacy_file_name' => $sourceName];
        $fileData = [];
        $isActive = true;
        $status = 'imported';

        if ($sourceName === '' || ! File::exists($sourcePath) || ! $this->extensionIsAllowed($extension)) {
            $metadata['warning'] = 'legacy_download_file_missing_or_blocked';
            $isActive = false;
            $status = 'missing_file';
        } else {
            $disk = config('filesystems.default');
            $targetPath = 'public-home/downloads/legacy-'.$record['id'].'/'.Str::uuid().'.'.$extension;
            Storage::disk($disk)->put($targetPath, File::get($sourcePath));
            $fileData = [
                'file_disk' => $disk,
                'file_path' => $targetPath,
                'file_original_name' => $this->safeOriginalName($record['title'], $extension),
                'file_mime_type' => File::mimeType($sourcePath),
                'file_extension' => $extension,
                'file_size_bytes' => File::size($sourcePath),
                'file_sha256' => hash_file('sha256', $sourcePath),
            ];
        }

        PublicHomeItem::updateOrCreate(
            ['legacy_source' => 'pro_cms', 'legacy_id' => $record['id']],
            [
                'section' => 'download',
                'title' => $record['title'],
                'summary' => null,
                'published_at' => $record['time'],
                'sort_order' => 1000 + $record['id'],
                'is_active' => $isActive,
                'metadata' => $metadata,
                ...$fileData,
            ]
        );

        return $status;
    }

    private function extensionIsAllowed(string $extension): bool
    {
        $allowed = $this->extensionList(config('modernization.upload_allowed_extensions'));
        $blocked = $this->extensionList(config('modernization.upload_blocked_extensions'));

        return $extension !== '' && in_array($extension, $allowed, true) && ! in_array($extension, $blocked, true);
    }

    private function extensionList(string $value): array
    {
        return array_values(array_filter(array_map(
            fn (string $extension) => strtolower(trim($extension, " \t\n\r\0\x0B.")),
            explode(',', $value)
        )));
    }

    private function safeOriginalName(string $title, string $extension): string
    {
        $name = preg_replace('/[\x00-\x1F\x7F\/\\\\:*?"<>|]+/u', ' ', $title) ?? '';
        $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '');

        return ($name !== '' ? $name : 'attachment').'.'.$extension;
    }

    private function summaryFromContent(?string $content): string
    {
        $text = trim(preg_replace('/\s+/u', ' ', html_entity_decode(strip_tags((string) $content))) ?? '');

        return Str::limit($text, 180, '');
    }

    private function summarize(array $records): array
    {
        $summary = ['notices' => 0, 'downloads' => 0, 'skipped' => 0];
        foreach ($records as $record) {
            if ($record['kind'] === 1) {
                $summary['notices']++;
            } elseif ($record['kind'] === 3) {
                $summary['downloads']++;
            } else {
                $summary['skipped']++;
            }
        }

        return $summary;
    }

    private function parseCmsRecords(string $sql): array
    {
        preg_match_all('/INSERT INTO `pro_cms` VALUES\s*(.*?);/s', $sql, $matches);
        $records = [];
        foreach ($matches[1] as $body) {
            foreach ($this->extractTuples($body) as $tuple) {
                $fields = str_getcsv($tuple, ',', "'", '\\');
                if (count($fields) < 6) {
                    continue;
                }

                $records[] = [
                    'id' => (int) $fields[0],
                    'kind' => (int) $fields[1],
                    'time' => $this->parseDate($this->cleanValue($fields[2])),
                    'title' => (string) $this->cleanValue($fields[3]),
                    'content' => (string) $this->cleanValue($fields[4]),
                    'ex_1' => (string) $this->cleanValue($fields[5]),
                ];
            }
        }

        return $records;
    }

    private function extractTuples(string $body): array
    {
        $tuples = [];
        $buffer = '';
        $level = 0;
        $inString = false;
        $escaped = false;
        $length = strlen($body);

        for ($i = 0; $i < $length; $i++) {
            $char = $body[$i];

            if ($char === "'" && ! $escaped) {
                $inString = ! $inString;
            }

            if (! $inString && $char === '(') {
                if ($level === 0) {
                    $buffer = '';
                    $level = 1;
                    continue;
                }
                $level++;
            }

            if (! $inString && $char === ')') {
                $level--;
                if ($level === 0) {
                    $tuples[] = $buffer;
                    $buffer = '';
                    continue;
                }
            }

            if ($level > 0) {
                $buffer .= $char;
            }

            $escaped = $char === '\\' && ! $escaped;
            if ($char !== '\\') {
                $escaped = false;
            }
        }

        return $tuples;
    }

    private function cleanValue(?string $value): ?string
    {
        if ($value === null || strtoupper($value) === 'NULL') {
            return null;
        }

        return stripcslashes($value);
    }

    private function parseDate(?string $value): ?Carbon
    {
        if (! $value) {
            return null;
        }

        return Carbon::parse($value);
    }
}
