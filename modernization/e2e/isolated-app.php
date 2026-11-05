<?php

use Illuminate\Foundation\Application;

$sandbox = getenv('NXM_QA_SANDBOX');
$runs = __DIR__.DIRECTORY_SEPARATOR.'reports'.DIRECTORY_SEPARATOR.'runs';
if (! is_string($sandbox) || ! is_dir($sandbox) || ! is_dir($runs)) {
    throw new RuntimeException('An existing isolated E2E sandbox is required.');
}
$sandbox = realpath($sandbox);
$runs = realpath($runs);
if (! str_starts_with(str_replace('\\', '/', $sandbox).'/', str_replace('\\', '/', $runs).'/')
    || basename($sandbox) !== 'sandbox') {
    throw new RuntimeException('Refusing a sandbox outside E2E report runs.');
}
foreach (['bootstrap/cache', 'storage/app/private', 'storage/framework/cache/data', 'storage/framework/sessions', 'storage/framework/views', 'storage/logs'] as $directory) {
    if (! is_dir($sandbox.'/'.$directory)) {
        mkdir($sandbox.'/'.$directory, 0700, true);
    }
}
$database = $sandbox.'/database.sqlite';
if (! file_exists($database)) {
    touch($database);
}
foreach ([
    'APP_ENV' => 'testing', 'APP_DEBUG' => 'false',
    'APP_KEY' => 'base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'APP_URL' => 'http://127.0.0.1:18742',
    'DB_CONNECTION' => 'sqlite', 'DB_DATABASE' => $database,
    'CACHE_STORE' => 'file', 'SESSION_DRIVER' => 'file',
    'MAIL_MAILER' => 'array', 'QUEUE_CONNECTION' => 'sync',
    'FILESYSTEM_DISK' => 'local',
    'APP_CONFIG_CACHE' => $sandbox.'/bootstrap/cache/config.php',
    'APP_ROUTES_CACHE' => $sandbox.'/bootstrap/cache/routes.php',
    'APP_PACKAGES_CACHE' => $sandbox.'/bootstrap/cache/packages.php',
    'APP_SERVICES_CACHE' => $sandbox.'/bootstrap/cache/services.php',
] as $key => $value) {
    putenv($key.'='.$value);
    $_ENV[$key] = $_SERVER[$key] = $value;
}
require_once __DIR__.'/../backend/vendor/autoload.php';
/** @var Application $app */
$app = require __DIR__.'/../backend/bootstrap/app.php';
if (preg_match('/^[A-Za-z]:/', $sandbox)) {
    $app->addAbsoluteCachePathPrefix(substr($sandbox, 0, 2));
}
$app->useEnvironmentPath($sandbox);
$app->useStoragePath($sandbox.'/storage');

return $app;
