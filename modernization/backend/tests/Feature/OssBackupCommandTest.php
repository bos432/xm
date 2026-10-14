<?php

namespace Tests\Feature;

require_once __DIR__.'/../../app/Console/Commands/UploadOssBackups.php';

use App\Support\RuntimeConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Output\BufferedOutput;
use Tests\TestCase;

class OssBackupCommandTest extends TestCase
{
    use RefreshDatabase;

    private function runOssBackup(string $database, string $files): array
    {
        $output = new BufferedOutput;
        $command = new \App\Console\Commands\UploadOssBackups;
        $command->setLaravel(app());
        $exitCode = $command->run(
            new ArrayInput(['--database' => $database, '--files' => $files]),
            $output,
        );

        return [$exitCode, $output->fetch()];
    }

    public function test_oss_backup_is_skipped_when_not_enabled(): void
    {
        $database = tempnam(sys_get_temp_dir(), 'nxm-db-');
        $files = tempnam(sys_get_temp_dir(), 'nxm-files-');
        file_put_contents($database, 'database archive');
        file_put_contents($files, 'private files archive');

        [$exitCode, $output] = $this->runOssBackup($database, $files);

        $this->assertSame(0, $exitCode);
        $this->assertStringContainsString('OSS backup is disabled; local archives are retained.', $output);
        Http::assertNothingSent();
    }

    public function test_enabled_oss_backup_uploads_both_archives_and_verifies_objects(): void
    {
        $database = tempnam(sys_get_temp_dir(), 'nxm-db-');
        $files = tempnam(sys_get_temp_dir(), 'nxm-files-');
        file_put_contents($database, 'database archive');
        file_put_contents($files, 'private files archive');

        $secret = 'oss-secret-'.Str::random(12);
        RuntimeConfig::set('backup.oss_enabled', '1', 'backup', false);
        RuntimeConfig::set('backup.oss_endpoint', 'https://oss-cn-huhehaote.aliyuncs.com', 'backup', false);
        RuntimeConfig::set('backup.oss_bucket', 'nxm-backup', 'backup', false);
        RuntimeConfig::set('backup.oss_prefix', 'nxm.zlck888.com/daily', 'backup', false);
        RuntimeConfig::set('backup.oss_access_key_id', 'test-access-key', 'backup', true);
        RuntimeConfig::set('backup.oss_access_key_secret', $secret, 'backup', true);
        $this->assertSame('1', RuntimeConfig::value('backup.oss_enabled'));

        $sent = 0;
        $heads = 0;
        Http::fake(function (Request $request) use (&$sent, &$heads, $secret) {
            $sent++;
            $method = $request->method();
            $date = $request->header('Date')[0];
            $contentType = $method === 'PUT' ? $request->header('Content-Type')[0] : '';
            $resource = '/nxm-backup/'.ltrim((string) parse_url($request->url(), PHP_URL_PATH), '/');
            $expectedSignature = base64_encode(hash_hmac(
                'sha1',
                implode("\n", [$method, '', $contentType, $date, $resource]),
                $secret,
                true
            ));
            if ($request->header('Authorization')[0] !== 'OSS test-access-key:'.$expectedSignature) {
                return Http::response('', 403);
            }

            if ($request->method() === 'PUT') {
                return Http::response('', 200);
            }

            $heads++;
            $size = $heads === 1 ? strlen('database archive') : strlen('private files archive');

            return Http::response('', 200, ['Content-Length' => (string) $size]);
        });

        [$exitCode, $output] = $this->runOssBackup($database, $files);

        $this->assertSame(0, $exitCode);
        $this->assertStringContainsString('Uploaded and verified 2 OSS backup objects.', $output);
        $this->assertSame(4, $sent);
        Http::assertSent(fn (Request $request) => $request->method() === 'PUT'
            && str_contains($request->url(), 'nxm-backup.oss-cn-huhehaote.aliyuncs.com/nxm.zlck888.com/daily/')
            && str_starts_with((string) $request->header('Authorization')[0], 'OSS test-access-key:')
            && $request->header('Content-Type')[0] === 'application/octet-stream');
        $this->assertStringNotContainsString($secret, $output);
    }

    public function test_oss_failure_returns_failure_but_keeps_local_archives(): void
    {
        $database = tempnam(sys_get_temp_dir(), 'nxm-db-');
        $files = tempnam(sys_get_temp_dir(), 'nxm-files-');
        file_put_contents($database, 'database archive');
        file_put_contents($files, 'private files archive');

        RuntimeConfig::set('backup.oss_enabled', '1', 'backup', false);
        RuntimeConfig::set('backup.oss_endpoint', 'https://oss-cn-huhehaote.aliyuncs.com', 'backup', false);
        RuntimeConfig::set('backup.oss_bucket', 'nxm-backup', 'backup', false);
        RuntimeConfig::set('backup.oss_prefix', 'nxm.zlck888.com/daily', 'backup', false);
        RuntimeConfig::set('backup.oss_access_key_id', 'test-access-key', 'backup', true);
        RuntimeConfig::set('backup.oss_access_key_secret', 'test-secret', 'backup', true);
        Http::fakeSequence()->push('', 503);

        [$exitCode, $output] = $this->runOssBackup($database, $files);

        $this->assertSame(1, $exitCode);
        $this->assertStringContainsString('OSS backup failed', $output);
        $this->assertFileExists($database);
        $this->assertFileExists($files);
    }

    public function test_invalid_endpoint_is_rejected_without_sending_requests(): void
    {
        $database = tempnam(sys_get_temp_dir(), 'nxm-db-');
        $files = tempnam(sys_get_temp_dir(), 'nxm-files-');
        file_put_contents($database, 'database archive');
        file_put_contents($files, 'private files archive');
        RuntimeConfig::set('backup.oss_enabled', '1', 'backup', false);
        RuntimeConfig::set('backup.oss_endpoint', 'https://attacker.example', 'backup', false);
        RuntimeConfig::set('backup.oss_bucket', 'nxm-backup', 'backup', false);
        RuntimeConfig::set('backup.oss_prefix', 'nxm.zlck888.com/daily', 'backup', false);
        RuntimeConfig::set('backup.oss_access_key_id', 'test-access-key', 'backup', true);
        RuntimeConfig::set('backup.oss_access_key_secret', 'test-secret', 'backup', true);
        Http::fake();

        [$exitCode, $output] = $this->runOssBackup($database, $files);

        $this->assertSame(1, $exitCode);
        $this->assertStringContainsString('regional Alibaba Cloud HTTPS endpoint', $output);
        Http::assertNothingSent();
    }

    public function test_prefix_traversal_is_rejected_without_sending_requests(): void
    {
        $database = tempnam(sys_get_temp_dir(), 'nxm-db-');
        $files = tempnam(sys_get_temp_dir(), 'nxm-files-');
        file_put_contents($database, 'database archive');
        file_put_contents($files, 'private files archive');
        RuntimeConfig::set('backup.oss_enabled', '1', 'backup', false);
        RuntimeConfig::set('backup.oss_endpoint', 'https://oss-cn-huhehaote.aliyuncs.com', 'backup', false);
        RuntimeConfig::set('backup.oss_bucket', 'nxm-backup', 'backup', false);
        RuntimeConfig::set('backup.oss_prefix', '../other-site', 'backup', false);
        RuntimeConfig::set('backup.oss_access_key_id', 'test-access-key', 'backup', true);
        RuntimeConfig::set('backup.oss_access_key_secret', 'test-secret', 'backup', true);
        Http::fake();

        [$exitCode, $output] = $this->runOssBackup($database, $files);

        $this->assertSame(1, $exitCode);
        $this->assertStringContainsString('unsupported path segments', $output);
        Http::assertNothingSent();
    }
}