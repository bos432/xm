param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-import-preview.json"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Test-PositiveInteger($value) {
    if (Test-Blank $value) { return $false }
    return [regex]::IsMatch([string]$value, '^[1-9][0-9]*$')
}

function Add-PreviewItem($items, $target, $sourceKey, $legacyId, $newValues, $status, $warnings, $approvedBy, $note) {
    $items.Add([pscustomobject][ordered]@{
        target = $target
        source_key = $sourceKey
        legacy_id = $legacyId
        new_values = $newValues
        status = $status
        warnings = @($warnings)
        approved_by = $approvedBy
        resolution_note = $note
    })
}

function Get-StatusCounts($items) {
    $counts = [ordered]@{ ready = 0; pending = 0; blocked = 0 }
    foreach ($item in @($items)) {
        if ($counts.Contains($item.status)) { $counts[$item.status]++ }
    }
    return $counts
}

$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$items = New-Object System.Collections.Generic.List[object]

foreach ($row in @($unitRows)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not (Test-PositiveInteger $row.legacy_unit_id)) { $warnings.Add('legacy_unit_id_invalid') }
    if (-not (Test-PositiveInteger $row.unit_id)) { $warnings.Add('unit_id_missing_or_invalid') }
    if (-not (Test-PositiveInteger $row.owner_id)) { $warnings.Add('owner_id_missing_or_invalid') }
    if (Test-Blank $row.approved_by) { $warnings.Add('approved_by_missing') }
    $status = if ($warnings.Count -eq 0) { 'ready' } elseif ((Test-Blank $row.unit_id) -and (Test-Blank $row.owner_id) -and (Test-Blank $row.approved_by)) { 'pending' } else { 'blocked' }
    Add-PreviewItem $items 'unit_user_mapping' 'unit_user_mapping_template' $row.legacy_unit_id ([ordered]@{ unit_id = $row.unit_id; owner_id = $row.owner_id }) $status @($warnings.ToArray()) $row.approved_by $row.resolution_note
}

foreach ($row in @($projectRows)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $warnings.Add('legacy_project_id_invalid') }
    if (-not (Test-PositiveInteger $row.new_project_id)) { $warnings.Add('new_project_id_missing_or_invalid') }
    if (Test-Blank $row.approved_by) { $warnings.Add('approved_by_missing') }
    $status = if ($warnings.Count -eq 0) { 'ready' } elseif ((Test-Blank $row.new_project_id) -and (Test-Blank $row.approved_by)) { 'pending' } else { 'blocked' }
    Add-PreviewItem $items 'project_mapping' 'project_mapping_template' $row.legacy_project_id ([ordered]@{ new_project_id = $row.new_project_id }) $status @($warnings.ToArray()) $row.approved_by $row.resolution_note
}

foreach ($row in @($attachmentRows)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()
    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $warnings.Add('legacy_project_id_invalid') }
    if (@('recover', 'exception') -notcontains $decision) { $warnings.Add('decision_missing_or_invalid') }
    elseif ($decision -eq 'recover' -and (Test-Blank $row.replacement_path)) { $warnings.Add('replacement_path_missing') }
    elseif ($decision -eq 'exception' -and (Test-Blank $row.exception_reason)) { $warnings.Add('exception_reason_missing') }
    if (Test-Blank $row.approved_by) { $warnings.Add('approved_by_missing') }
    $allDecisionBlank = (Test-Blank $row.decision) -and (Test-Blank $row.replacement_path) -and (Test-Blank $row.exception_reason) -and (Test-Blank $row.approved_by)
    $status = if ($warnings.Count -eq 0) { 'ready' } elseif ($allDecisionBlank) { 'pending' } else { 'blocked' }
    Add-PreviewItem $items 'attachment_exception' 'attachment_exception_template' $row.legacy_id ([ordered]@{ legacy_project_id = $row.legacy_project_id; decision = $decision; replacement_path = $row.replacement_path; exception_reason = $row.exception_reason }) $status @($warnings.ToArray()) $row.approved_by ''
}

$byTarget = @()
foreach ($target in @('unit_user_mapping', 'project_mapping', 'attachment_exception')) {
    $targetItems = @($items.ToArray() | Where-Object { $_.target -eq $target })
    $counts = Get-StatusCounts $targetItems
    $byTarget += [ordered]@{
        target = $target
        total = $targetItems.Count
        ready = $counts.ready
        pending = $counts.pending
        blocked = $counts.blocked
    }
}

$statusCounts = Get-StatusCounts @($items.ToArray())
$readyItems = @($items.ToArray() | Where-Object { $_.status -eq 'ready' })
$blockedItems = @($items.ToArray() | Where-Object { $_.status -eq 'blocked' })
$pendingItems = @($items.ToArray() | Where-Object { $_.status -eq 'pending' })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report parses operator CSV templates only. It does not update mapping reports, copy files, or write database records.'
    summary = [ordered]@{
        total_items = $items.Count
        ready_items = $statusCounts.ready
        pending_items = $statusCounts.pending
        blocked_items = $statusCounts.blocked
        unit_user_rows = @($unitRows).Count
        project_rows = @($projectRows).Count
        attachment_exception_rows = @($attachmentRows).Count
    }
    by_target = @($byTarget)
    samples = [ordered]@{
        ready = @($readyItems | Select-Object -First $SampleSize)
        pending = @($pendingItems | Select-Object -First $SampleSize)
        blocked = @($blockedItems | Select-Object -First $SampleSize)
    }
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution import preview written to $ReportPath"
