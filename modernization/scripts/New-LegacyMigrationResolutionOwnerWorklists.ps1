param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-worklists.json"),
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.json"),
    [string]$OutputDirectory = $PSScriptRoot,
    [string]$FilePrefix = "legacy-migration-resolution-worklist"
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Format-SampleRows($rows) {
    $items = @()
    foreach ($row in @($rows)) {
        $items += "#$($row.row_number):$($row.legacy_id)"
    }
    return ($items -join ';')
}

function ConvertTo-SafeFilePart($value) {
    $text = ([string]$value).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unassigned' }
    $text = [regex]::Replace($text, '[^a-z0-9_-]+', '_')
    $text = [regex]::Replace($text, '_+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unassigned' }
    return $text
}

function New-CsvRow($item) {
    return [pscustomobject][ordered]@{
        priority = $item.priority
        owner = $item.owner
        template = $item.template
        target = $item.target
        field_group = $item.field_group
        status = $item.status
        row_count = $item.row_count
        sample_rows = Format-SampleRows $item.sample_rows
        action = $item.action
        acceptance = $item.acceptance
    }
}

$worklist = Read-JsonReport $WorklistPath
$items = if ($worklist -and $worklist.items) { @($worklist.items) } else { @() }
$owners = @($items | Group-Object -Property owner | Sort-Object -Property Name)
$ownerFiles = New-Object System.Collections.Generic.List[object]

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

foreach ($owner in $owners) {
    $ownerName = if ([string]::IsNullOrWhiteSpace([string]$owner.Name)) { 'unassigned' } else { $owner.Name }
    $safeOwner = ConvertTo-SafeFilePart $ownerName
    $csvPath = Join-Path $OutputDirectory "$FilePrefix.$safeOwner.csv"
    $ownerItems = @($owner.Group | Sort-Object -Property priority, template, field_group)
    $csvRows = @($ownerItems | ForEach-Object { New-CsvRow $_ })

    $csvRows | Export-Csv -LiteralPath $csvPath -Encoding UTF8 -NoTypeInformation

    $ownerFiles.Add([pscustomobject][ordered]@{
        owner = $ownerName
        key = "owner_worklist_$safeOwner"
        path = $csvPath
        work_items = $ownerItems.Count
        row_count = [int](@($ownerItems | Measure-Object -Property row_count -Sum).Sum)
        p1_items = @($ownerItems | Where-Object { $_.priority -eq 'P1' }).Count
        blocked_items = @($ownerItems | Where-Object { $_.status -eq 'blocked' }).Count
    })
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report splits the migration resolution worklist into owner-specific CSV files. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if (-not $worklist) { 'missing' } elseif ($worklist.overall_status -eq 'blocked') { 'blocked' } elseif ($ownerFiles.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        owner_count = $ownerFiles.Count
        work_items = if ($worklist) { $worklist.summary.work_items } else { 0 }
        total_rows = if ($worklist) { $worklist.summary.total_rows } else { 0 }
        ready_rows = if ($worklist) { $worklist.summary.ready_rows } else { 0 }
        pending_rows = if ($worklist) { $worklist.summary.pending_rows } else { 0 }
        blocked_rows = if ($worklist) { $worklist.summary.blocked_rows } else { 0 }
        p1_items = if ($worklist) { $worklist.summary.p1_items } else { 0 }
        blocked_items = if ($worklist) { $worklist.summary.blocked_items } else { 0 }
    }
    files = @($ownerFiles.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution owner worklists written to $ReportPath"
