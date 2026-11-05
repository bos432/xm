param(
    [Parameter(Mandatory = $true)][string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
$backend = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$containerName = 'nxm-qa-mysql57-20261105'
$container = @(docker inspect $containerName | ConvertFrom-Json)[0]
if ($LASTEXITCODE -ne 0 -or -not $container.State.Running -or
    $container.Config.Labels.'nxm.qa.scope' -ne 'isolated-concurrency' -or
    $container.NetworkSettings.Ports.'3306/tcp'[0].HostIp -ne '127.0.0.1' -or
    $container.NetworkSettings.Ports.'3306/tcp'[0].HostPort -ne '13371') {
    throw 'Expected running loopback-only isolated QA container was not found'
}
$passwordEntry = $container.Config.Env | Where-Object { $_ -like 'MYSQL_ROOT_PASSWORD=*' }
if (-not $passwordEntry) { throw 'Isolated database credential absent' }

$settings = @{
    APP_ENV = 'testing'
    APP_KEY = 'base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    APP_DEBUG = 'false'
    DB_CONNECTION = 'mysql'
    DB_HOST = '127.0.0.1'
    DB_PORT = '13371'
    DB_DATABASE = 'modernization_migration_test'
    DB_USERNAME = 'root'
    DB_PASSWORD = $passwordEntry.Substring('MYSQL_ROOT_PASSWORD='.Length)
    DB_URL = ''
    DB_SOCKET = ''
    QA_EXPECTED_DB_DRIVER = 'mysql'
    APP_CONFIG_CACHE = Join-Path $env:TEMP 'nxm-qa28-no-config.php'
    CACHE_STORE = 'array'
    MAIL_MAILER = 'array'
    QUEUE_CONNECTION = 'sync'
    SESSION_DRIVER = 'array'
    BCRYPT_ROUNDS = '4'
}
$previous = @{}
foreach ($key in $settings.Keys) {
    $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process')
}
$result = 1
Push-Location $backend
try {
    php artisan migrate --force --no-interaction
    if ($LASTEXITCODE -ne 0) { throw 'Isolated migrations failed' }
    php tests/Concurrency/lifecycle-race.php | Tee-Object -FilePath $EvidencePath
    $result = $LASTEXITCODE
} finally {
    Pop-Location
    foreach ($key in $settings.Keys) {
        [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process')
    }
}
exit $result
