param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-import-dry-run.json")
)

$ErrorActionPreference = 'Stop'

$tableMap = [ordered]@{
    pro_unit      = 'units'
    pro_manage    = 'users'
    pro_root      = 'users'
    pro_pro       = 'projects'
    pro_file      = 'project_files'
    pro_review    = 'project_reviews'
    pro_check_log = 'project_reviews'
    pro_log       = 'operation_logs'
}

if (-not (Test-Path -LiteralPath $SqlDump)) {
    throw "SQL dump not found: $SqlDump"
}

$content = Get-Content -LiteralPath $SqlDump -Raw
$items = @()

foreach ($entry in $tableMap.GetEnumerator()) {
    $legacyTable = $entry.Key
    $targetTable = $entry.Value
    $createFound = $content.Contains("CREATE TABLE ``$legacyTable``")
    $insertMatches = [regex]::Matches($content, "INSERT INTO ``$([regex]::Escape($legacyTable))``.*?;", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $estimatedRows = 0

    foreach ($match in $insertMatches) {
        $statement = $match.Value
        $rowSeparators = ([regex]::Matches($statement, "\),\s*\(")).Count
        $estimatedRows += [Math]::Max(1, $rowSeparators + 1)
    }

    $warnings = @()
    if (-not $createFound) {
        $warnings += 'missing_create_table'
    }
    if ($createFound -and $insertMatches.Count -eq 0) {
        $warnings += 'no_insert_statements'
    }

    $items += [ordered]@{
        legacy_table           = $legacyTable
        target_table           = $targetTable
        status                 = if ($warnings.Count -gt 0) { 'warning' } else { 'ready' }
        create_found           = $createFound
        insert_statement_count = $insertMatches.Count
        estimated_row_count    = $estimatedRows
        warnings               = $warnings
    }
}

$report = [ordered]@{
    generated_at        = (Get-Date -Format o)
    sql_dump            = $SqlDump
    mode                = 'dry_run'
    table_count         = $items.Count
    ready_count         = ($items | Where-Object { $_.status -eq 'ready' }).Count
    warning_count       = ($items | Where-Object { $_.warnings.Count -gt 0 }).Count
    estimated_row_count = [int](($items | ForEach-Object { $_['estimated_row_count'] } | Measure-Object -Sum).Sum)
    items               = $items
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Report written to $ReportPath"
