<?php

// Run only on this site's server: php <script> --verify-existing-nxm-backups.
$root = '/www/wwwroot/nxm.zlck888.com';
$backend = realpath($root.'/current/backend');
if (($argv[1] ?? '') !== '--verify-existing-nxm-backups' || ! $backend
    || ! str_starts_with($backend, $root.'/releases/') || realpath(getcwd()) !== $backend) {
    fwrite(STDERR, "Refusing execution outside the explicitly approved site backend.\n");
    exit(2);
}

require $backend.'/vendor/autoload.php';
$app = require $backend.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$report = ['stage' => 'QA-44', 'mode' => 'read_only_existing_objects', 'results' => []];
$ok = true;
try {
    if (! $app->environment('production') || ! App\Support\RuntimeConfig::boolValue('backup.oss_enabled')) {
        throw new RuntimeException('Expected production site with OSS enabled');
    }
    $values = [];
    foreach (['endpoint', 'bucket', 'prefix', 'access_key_id', 'access_key_secret'] as $name) {
        $values[$name] = trim((string) App\Support\RuntimeConfig::value('backup.oss_'.$name));
        if ($values[$name] === '') {
            throw new RuntimeException('Incomplete OSS settings');
        }
    }
    $endpoint = parse_url($values['endpoint']);
    if (($endpoint['scheme'] ?? '') !== 'https'
        || ! preg_match('/^oss-[a-z0-9-]+\.aliyuncs\.com$/', $endpoint['host'] ?? '')
        || array_intersect(['user', 'pass', 'port', 'query', 'fragment'], array_keys($endpoint))
        || ! in_array($endpoint['path'] ?? '', ['', '/'], true)
        || ! preg_match('/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/', $values['bucket'])
        || ! preg_match('/^[A-Za-z0-9._\/-]+$/', $values['prefix']) || str_contains($values['prefix'], '..')) {
        throw new RuntimeException('OSS endpoint or scope does not match the regional HTTPS contract');
    }
    $archives = glob($root.'/shared/backups/daily/nxm-database-*.sql.gz');
    rsort($archives, SORT_STRING);
    $database = $archives[0] ?? '';
    if (! preg_match('/nxm-database-(\d{8}-\d{6})\.sql\.gz$/', $database, $match)) {
        throw new RuntimeException('No database archive found');
    }
    $pair = [$database, dirname($database).'/nxm-private-files-'.$match[1].'.tar.gz'];
    foreach ($pair as $file) {
        if (! is_file($file) || filesize($file) < 1 || filesize($file) > 32 * 1024 * 1024) {
            throw new RuntimeException('Archive pair missing, empty or exceeds 32 MiB per-object limit');
        }
    }
    foreach ($pair as $file) {
        $object = trim($values['prefix'], '/').'/'.basename($file);
        $url = 'https://'.$values['bucket'].'.'.$endpoint['host'].'/'.implode('/', array_map('rawurlencode', explode('/', $object)));
        $result = ['archive' => basename($file), 'local_bytes' => filesize($file), 'head_status' => null, 'get_status' => null];
        $stream = tmpfile();
        if ($stream === false) {
            throw new RuntimeException('Could not allocate private temporary download');
        }
        try {
            foreach (['HEAD', 'GET'] as $method) {
                $date = gmdate('D, d M Y H:i:s').' GMT';
                $canonical = implode("\n", [$method, '', '', $date, '/'.$values['bucket'].'/'.$object]);
                $signature = base64_encode(hash_hmac('sha1', $canonical, $values['access_key_secret'], true));
                $curl = curl_init($url);
                $bytes = 0;
                $hash = hash_init('sha256');
                curl_setopt_array($curl, [CURLOPT_HTTPHEADER => ['Authorization: OSS '.$values['access_key_id'].':'.$signature, 'Date: '.$date],
                    CURLOPT_FOLLOWLOCATION => false, CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 30,
                    CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2, CURLOPT_NOBODY => $method === 'HEAD',
                    CURLOPT_RETURNTRANSFER => $method === 'HEAD']);
                if ($method === 'GET') {
                    curl_setopt($curl, CURLOPT_WRITEFUNCTION, function ($handle, string $chunk) use (&$bytes, $stream, $hash): int {
                        $bytes += strlen($chunk);
                        if ($bytes > 32 * 1024 * 1024) {
                            return 0;
                        }
                        hash_update($hash, $chunk);

                        return fwrite($stream, $chunk);
                    });
                }
                $transfer = curl_exec($curl);
                $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
                $length = (int) curl_getinfo($curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD);
                $error = curl_errno($curl);
                curl_close($curl);
                $result[strtolower($method).'_status'] = $status;
                if ($transfer === false || $status !== 200 || $length !== filesize($file)) {
                    $result['curl_errno'] = $error;
                    $ok = false;
                    break;
                }
                if ($method === 'GET') {
                    $result['download_bytes'] = $bytes;
                    $result['sha256_matches'] = hash_equals(hash_file('sha256', $file), hash_final($hash));
                    fflush($stream);
                    $gzip = gzopen(stream_get_meta_data($stream)['uri'], 'rb');
                    if ($gzip === false) {
                        throw new RuntimeException('Could not open downloaded gzip');
                    }
                    $expanded = 0;
                    $gzipOk = true;
                    try {
                        while (! gzeof($gzip)) {
                            $chunk = @gzread($gzip, 65536);
                            if ($chunk === false || ($chunk === '' && ! gzeof($gzip))) {
                                $gzipOk = false;
                                break;
                            }
                            $expanded += strlen($chunk);
                            if ($expanded > 256 * 1024 * 1024) {
                                $gzipOk = false;
                                break;
                            }
                        }
                    } finally {
                        gzclose($gzip);
                    }
                    $result['gzip_read_complete'] = $gzipOk && $expanded > 0;
                    $result['passed'] = $bytes === filesize($file) && $result['sha256_matches'] && $result['gzip_read_complete'];
                    $ok = $ok && $result['passed'];
                }
            }
        } finally {
            fclose($stream);
        }
        $result['temporary_download_closed'] = true;
        $report['results'][] = $result;
    }
} catch (Throwable $error) {
    $ok = false;
    // Deliberately omit exception text: HTTP libraries can include signed URLs or headers.
    $report['error_type'] = get_class($error);
}
$report['passed'] = $ok && count($report['results']) === 2;
$report['database_import_performed'] = false;
$report['production_business_data_or_config_modified'] = false;
echo json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), PHP_EOL;
exit($report['passed'] ? 0 : 1);
