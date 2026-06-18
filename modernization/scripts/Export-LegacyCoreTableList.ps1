param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-core-tables.txt")
)

$ErrorActionPreference = 'Stop'

$coreTables = @(
    'pro_unit',
    'pro_pro',
    'pro_file',
    'pro_review',
    'pro_log',
    'pro_manage',
    'pro_root',
    'pro_message',
    'pro_config',
    'pro_dept',
    'pro_city',
    'pro_projecttype'
)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Legacy core table extraction")
$lines.Add("SqlDump: $SqlDump")
$lines.Add("GeneratedAt: $(Get-Date -Format o)")
$lines.Add('')

foreach ($table in $coreTables) {
    $pattern = "CREATE TABLE ``$table``"
    $match = Select-String -LiteralPath $SqlDump -Pattern $pattern -SimpleMatch | Select-Object -First 1
    if ($match) {
        $lines.Add("FOUND $table at line $($match.LineNumber)")
    } else {
        $lines.Add("MISSING $table")
    }
}

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Report written to $ReportPath"

