param(
    [string]$WorkflowDryRunPath = (Join-Path $PSScriptRoot "legacy-workflow-db-dry-run.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Get-Field($row, $name, $default = '') {
    if ($null -eq $row) { return $default }
    if ($row.PSObject.Properties.Name -contains $name) { return $row.$name }
    return $default
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function New-SignoffRow($record, $existingRow) {
    $decision = (Get-Field $existingRow 'decision' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $decision) { $decision = 'pending' }

    return [pscustomobject][ordered]@{
        decision = $decision
        legacy_id = $record.legacy_id
        legacy_project_id = $record.legacy_project_id
        source_table = $record.source_table
        stage = $record.stage
        decision_text = $record.decision
        reviewed_at = $record.reviewed_at
        comment_excerpt = $record.comment_excerpt
        target_project_id = Get-Field $existingRow 'target_project_id'
        approved_by = Get-Field $existingRow 'approved_by'
        approved_at = Get-Field $existingRow 'approved_at'
        evidence_ref = Get-Field $existingRow 'evidence_ref'
        notes = Get-Field $existingRow 'notes'
    }
}

if (-not (Test-Path -LiteralPath $WorkflowDryRunPath -PathType Leaf)) {
    throw "Workflow dry-run report not found: $WorkflowDryRunPath"
}

$workflow = Get-Content -LiteralPath $WorkflowDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
$orphanRecords = @($workflow.reviews | Where-Object { $_.warnings -contains 'orphan_project_reference' })

$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = ([string](Get-Field $row 'legacy_id')).Trim().ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$validDecisions = @('pending', 'archive', 'link', 'exclude', 'blocked')
foreach ($record in @($orphanRecords)) {
    $key = ([string]$record.legacy_id).Trim().ToLowerInvariant()
    $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
    $rows.Add((New-SignoffRow $record $existingRow))
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pending = @($rows.ToArray() | Where-Object { $_.decision -eq 'pending' }).Count
$archive = @($rows.ToArray() | Where-Object { $_.decision -eq 'archive' }).Count
$link = @($rows.ToArray() | Where-Object { $_.decision -eq 'link' }).Count
$exclude = @($rows.ToArray() | Where-Object { $_.decision -eq 'exclude' }).Count
$blocked = @($rows.ToArray() | Where-Object { $_.decision -eq 'blocked' }).Count
$invalid = @($rows.ToArray() | Where-Object { $validDecisions -notcontains $_.decision }).Count

$byLegacyProject = @()
foreach ($group in @($rows.ToArray() | Group-Object legacy_project_id)) {
    $byLegacyProject += [ordered]@{ legacy_project_id = $group.Name; orphan_rows = $group.Count }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks handling decisions for workflow rows that reference missing legacy projects. It does not import records, link records, exclude records, or write database records.'
    overall_status = if ($invalid -gt 0 -or $blocked -gt 0) { 'blocked' } elseif (($archive + $link + $exclude) -eq $rows.Count) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        orphan_items = $rows.Count
        pending_items = $pending
        archive_items = $archive
        link_items = $link
        exclude_items = $exclude
        blocked_items = $blocked
        invalid_items = $invalid
        legacy_project_count = @($byLegacyProject).Count
    }
    by_legacy_project = @($byLegacyProject)
    csv_path = $CsvPath
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy workflow orphan resolution signoff written to $ReportPath"
Write-Host "Legacy workflow orphan resolution signoff CSV written to $CsvPath"
