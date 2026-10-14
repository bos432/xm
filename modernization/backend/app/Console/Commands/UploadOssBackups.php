<?php

namespace App\Console\Commands;

use App\Support\RuntimeConfig;
use Illuminate\Console\Command;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class UploadOssBackups extends Command
{
    protected $signature = 'site:backup:oss
                            {--database= : Verified database archive path}
                            {--files= : Verified private-upload archive path}';

    protected $description = 'Upload this site backup archives to the configured Alibaba Cloud OSS bucket.';

    public function handle(): int
    {
        if (! RuntimeConfig::boolValue('backup.oss_enabled')) {
            $this->info('OSS backup is disabled; local archives are retained.');

            return self::SUCCESS;
        }

        $database = (string) $this->option('database');
        $files = (string) $this->option('files');
        foreach ([$database, $files] as $archive) {
            if ($archive === '' || ! is_file($archive) || ! is_readable($archive) || filesize($archive) < 1) {
                $this->error('OSS backup failed: a local archive is missing or unreadable.');

                return self::FAILURE;
            }
        }

        try {
            $endpoint = $this->endpoint();
            $bucket = $this->required('backup.oss_bucket');
            $prefix = $this->prefix();
            $accessKey = $this->required('backup.oss_access_key_id');
            $secret = $this->required('backup.oss_access_key_secret');
            $uploaded = 0;

            foreach ([$database, $files] as $archive) {
                $object = $prefix.'/'.basename($archive);
                $this->putAndVerify($endpoint, $bucket, $object, $accessKey, $secret, $archive);
                $uploaded++;
            }

            $this->info("Uploaded and verified {$uploaded} OSS backup objects.");

            return self::SUCCESS;
        } catch (\Throwable $exception) {
            $this->error('OSS backup failed: '.$this->safeMessage($exception));

            return self::FAILURE;
        }
    }

    private function putAndVerify(string $endpoint, string $bucket, string $object, string $accessKey, string $secret, string $archive): void
    {
        $stream = fopen($archive, 'rb');
        if ($stream === false) {
            throw new RuntimeException('could not read local archive');
        }
        if (filesize($archive) >= 5_000_000_000) {
            fclose($stream);
            throw new RuntimeException('archive exceeds the 5 GB single-request upload limit');
        }

        $date = gmdate('D, d M Y H:i:s').' GMT';
        $contentType = 'application/octet-stream';
        $resource = '/'.$bucket.'/'.$object;
        $signature = $this->signature('PUT', '', $contentType, $date, $resource, $secret);
        $url = 'https://'.$bucket.'.'.parse_url($endpoint, PHP_URL_HOST).'/'.$this->encodeObject($object);
        try {
            $request = $this->client($accessKey, $signature, $date, $contentType)
                ->withBody($stream, $contentType)
                ->put($url);
        } finally {
            fclose($stream);
        }

        if (! $request->successful()) {
            throw new RuntimeException('OSS PUT returned HTTP '.$request->status());
        }

        $headDate = gmdate('D, d M Y H:i:s').' GMT';
        $headSignature = $this->signature('HEAD', '', '', $headDate, $resource, $secret);
        $head = $this->client($accessKey, $headSignature, $headDate, null)->head($url);
        $expected = (string) filesize($archive);
        if (! $head->successful() || (string) $head->header('Content-Length') !== $expected) {
            throw new RuntimeException('OSS object verification failed');
        }
    }

    private function client(string $accessKey, string $signature, string $date, ?string $contentType): PendingRequest
    {
        $headers = [
            'Authorization' => 'OSS '.$accessKey.':'.$signature,
            'Date' => $date,
        ];
        if ($contentType !== null) {
            $headers['Content-Type'] = $contentType;
        }

        return Http::withHeaders($headers)->withoutRedirecting()->connectTimeout(15)->timeout(120);
    }

    private function signature(string $method, string $contentMd5, string $contentType, string $date, string $resource, string $secret): string
    {
        $stringToSign = implode("\n", [$method, $contentMd5, $contentType, $date, $resource]);

        return base64_encode(hash_hmac('sha1', $stringToSign, $secret, true));
    }

    private function endpoint(): string
    {
        $value = rtrim($this->required('backup.oss_endpoint'), '/');
        $parts = parse_url($value);
        if (! is_array($parts) || ($parts['scheme'] ?? '') !== 'https' || empty($parts['host'])
            || isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment'])
            || isset($parts['port']) || ! in_array($parts['path'] ?? '', ['', '/'], true)
            || ! preg_match('/^(?:oss-[a-z0-9-]+|[a-z0-9-]+\.oss-[a-z0-9-]+)\.aliyuncs\.com$/', $parts['host'])) {
            throw new RuntimeException('OSS endpoint must be a regional Alibaba Cloud HTTPS endpoint without credentials or query parameters');
        }

        return 'https://'.$parts['host'];
    }

    private function prefix(): string
    {
        $prefix = trim($this->required('backup.oss_prefix'), '/');
        if ($prefix === '' || str_contains($prefix, '..') || ! preg_match('/^[A-Za-z0-9._\/-]+$/', $prefix)) {
            throw new RuntimeException('OSS prefix contains unsupported path segments');
        }

        return $prefix;
    }

    private function required(string $key): string
    {
        $value = trim((string) RuntimeConfig::value($key, ''));
        if ($value === '') {
            throw new RuntimeException('OSS configuration is incomplete');
        }

        return $value;
    }

    private function encodeObject(string $object): string
    {
        return implode('/', array_map('rawurlencode', explode('/', $object)));
    }

    private function safeMessage(\Throwable $exception): string
    {
        $message = $exception->getMessage();
        foreach ([RuntimeConfig::value('backup.oss_access_key_id', ''), RuntimeConfig::value('backup.oss_access_key_secret', '')] as $secret) {
            if ($secret !== '') {
                $message = str_replace($secret, '[redacted]', $message);
            }
        }

        return $message !== '' ? $message : 'request error';
    }
}
