param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-template-row-worklists.json"),
    [string]$RowWorklistCsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-row-worklist.csv"),
    [string]$OutputDirectory = $PSScriptRoot,
    [string]$FilePrefix = "legacy-migration-resolution-row-worklist"
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function ConvertTo-SafeFilePart($value) {
    $text = ([string]$value).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unassigned' }
    $text = $text -replace '\.template\.csv$', ''
    $text = $text -replace '^legacy-', ''
    $text = [regex]::Replace($text, '[^a-z0-9_-]+', '_')
    $text = [regex]::Replace($text, '_+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unassigned' }
    return $text
}

function New-FileSummary($ownerName, $templateName, $safeOwner, $safeTemplate, $rows, $path) {
    return [pscustomobject][ordered]@{
        owner = $ownerName
        template = $templateName
        key = "owner_template_row_worklist_$safeOwner`_$safeTemplate"
        path = $path
        rows = @($rows).Count
        p1_rows = @($rows | Where-Object { $_.priority -eq 'P1' }).Count
        blocked_rows = @($rows | Where-Object { $_.status -eq 'blocked' }).Count
    }
}

$rows = Read-CsvRows $RowWorklistCsvPath
$files = New-Object System.Collections.Generic.List[object]

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

$groups = @($rows | Group-Object owner, template | Sort-Object Name)
foreach ($group in $groups) {
    $groupRows = @($group.Group | Sort-Object -Property priority, row_number)
    if ($groupRows.Count -eq 0) { continue }

    $ownerName = if ([string]::IsNullOrWhiteSpace([string]$groupRows[0].owner)) { 'unassigned' } else { $groupRows[0].owner }
    $templateName = if ([string]::IsNullOrWhiteSpace([string]$groupRows[0].template)) { 'unknown_template' } else { $groupRows[0].template }
    $safeOwner = ConvertTo-SafeFilePart $ownerName
    $safeTemplate = ConvertTo-SafeFilePart $templateName
    $csvPath = Join-Path $OutputDirectory "$FilePrefix.$safeOwner.$safeTemplate.csv"

    $groupRows | Export-Csv -LiteralPath $csvPath -Encoding UTF8 -NoTypeInformation
    $files.Add((New-FileSummary $ownerName $templateName $safeOwner $safeTemplate $groupRows $csvPath))
}

$blockedRows = @($rows | Where-Object { $_.status -eq 'blocked' }).Count
$p1Rows = @($rows | Where-Object { $_.priority -eq 'P1' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report splits row-level resolution work items by owner and template. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if (-not (Test-Path -LiteralPath $RowWorklistCsvPath -PathType Leaf)) { 'missing' } elseif ($blockedRows -gt 0) { 'blocked' } elseif ($rows.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        file_count = $files.Count
        row_work_items = $rows.Count
        p1_rows = $p1Rows
        blocked_rows = $blockedRows
    }
    files = @($files.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution owner template row worklists written to $ReportPath"
