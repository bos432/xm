param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-row-worklists.json"),
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
    $text = [regex]::Replace($text, '[^a-z0-9_-]+', '_')
    $text = [regex]::Replace($text, '_+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unassigned' }
    return $text
}

function New-OwnerSummary($ownerName, $safeOwner, $rows, $path) {
    return [pscustomobject][ordered]@{
        owner = $ownerName
        key = "owner_row_worklist_$safeOwner"
        path = $path
        rows = @($rows).Count
        p1_rows = @($rows | Where-Object { $_.priority -eq 'P1' }).Count
        blocked_rows = @($rows | Where-Object { $_.status -eq 'blocked' }).Count
        templates = @($rows | Group-Object template | Sort-Object Name | ForEach-Object {
            [pscustomobject][ordered]@{
                template = $_.Name
                rows = $_.Count
                p1_rows = @($_.Group | Where-Object { $_.priority -eq 'P1' }).Count
                blocked_rows = @($_.Group | Where-Object { $_.status -eq 'blocked' }).Count
            }
        })
    }
}

$rows = Read-CsvRows $RowWorklistCsvPath
$ownerFiles = New-Object System.Collections.Generic.List[object]

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

$owners = @($rows | Group-Object owner | Sort-Object Name)
foreach ($owner in $owners) {
    $ownerName = if ([string]::IsNullOrWhiteSpace([string]$owner.Name)) { 'unassigned' } else { $owner.Name }
    $safeOwner = ConvertTo-SafeFilePart $ownerName
    $csvPath = Join-Path $OutputDirectory "$FilePrefix.$safeOwner.csv"
    $ownerRows = @($owner.Group | Sort-Object -Property priority, template, row_number)

    $ownerRows | Export-Csv -LiteralPath $csvPath -Encoding UTF8 -NoTypeInformation
    $ownerFiles.Add((New-OwnerSummary $ownerName $safeOwner $ownerRows $csvPath))
}

$blockedRows = @($rows | Where-Object { $_.status -eq 'blocked' }).Count
$p1Rows = @($rows | Where-Object { $_.priority -eq 'P1' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report splits row-level resolution work items into owner-specific CSV files. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if (-not (Test-Path -LiteralPath $RowWorklistCsvPath -PathType Leaf)) { 'missing' } elseif ($blockedRows -gt 0) { 'blocked' } elseif ($rows.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        owner_count = $ownerFiles.Count
        row_work_items = $rows.Count
        p1_rows = $p1Rows
        blocked_rows = $blockedRows
    }
    files = @($ownerFiles.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution owner row worklists written to $ReportPath"
