param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-confirmation.json"),
    [string]$AttachmentDryRunPath = (Join-Path $PSScriptRoot "legacy-attachment-import-dry-run.json"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function New-Key($sourceTable, $legacyId, $projectId, $field) {
    return "$sourceTable|$legacyId|$projectId|$field"
}

function Get-DecisionStatus($row) {
    if (-not $row) { return [ordered]@{ status = 'pending'; warnings = @('exception_csv_row_missing'); action = 'Add a row to legacy-attachment-exceptions.template.csv.' } }

    $warnings = New-Object System.Collections.Generic.List[string]
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()

    if (Test-Blank $decision) { $warnings.Add('decision_missing') }
    elseif (@('recover', 'exception') -notcontains $decision) { $warnings.Add('decision_invalid') }
    elseif ($decision -eq 'recover' -and (Test-Blank $row.replacement_path)) { $warnings.Add('replacement_path_missing') }
    elseif ($decision -eq 'exception' -and (Test-Blank $row.exception_reason)) { $warnings.Add('exception_reason_missing') }

    if (Test-Blank $row.approved_by) { $warnings.Add('approved_by_missing') }

    $allOperatorBlank = (Test-Blank $row.decision) -and (Test-Blank $row.replacement_path) -and (Test-Blank $row.exception_reason) -and (Test-Blank $row.approved_by)
    $status = if ($warnings.Count -eq 0) { 'ready' } elseif ($allOperatorBlank) { 'pending' } else { 'blocked' }
    $action = if ($status -eq 'ready') {
        'Decision is complete and ready for resolved exception preview.'
    } elseif ($status -eq 'pending') {
        'Choose recover or exception, then fill the matching field and approved_by.'
    } else {
        'Fix the partially filled decision row before resolved exception preview.'
    }

    return [ordered]@{
        status = $status
        warnings = @($warnings.ToArray())
        action = $action
    }
}

$dryRun = Read-JsonReport $AttachmentDryRunPath
$exceptionRows = Read-CsvRows $AttachmentExceptionCsvPath

$exceptionByKey = @{}
foreach ($row in @($exceptionRows)) {
    $key = New-Key $row.source_table $row.legacy_id $row.legacy_project_id $row.field
    $exceptionByKey[$key] = $row
}

$blockedItems = @()
if ($dryRun -and $dryRun.samples -and $dryRun.samples.blocked) {
    $blockedItems = @($dryRun.samples.blocked)
}

$items = New-Object System.Collections.Generic.List[object]
foreach ($item in @($blockedItems)) {
    $key = New-Key $item.source_table $item.legacy_id $item.legacy_project_id $item.field
    $row = if ($exceptionByKey.ContainsKey($key)) { $exceptionByKey[$key] } else { $null }
    $decision = Get-DecisionStatus $row
    $decisionValue = if ($row) { ([string]$row.decision).Trim().ToLowerInvariant() } else { '' }

    $items.Add([pscustomobject][ordered]@{
        source_table = $item.source_table
        legacy_id = $item.legacy_id
        legacy_project_id = $item.legacy_project_id
        field = $item.field
        source_path = $item.source_path
        raw_path = $item.raw_path
        original_name = $item.original_name
        target_path = $item.target_path
        dry_run_warnings = @($item.warnings)
        decision = $decisionValue
        replacement_path = if ($row) { $row.replacement_path } else { '' }
        exception_reason = if ($row) { $row.exception_reason } else { '' }
        approved_by = if ($row) { $row.approved_by } else { '' }
        status = $decision.status
        warnings = @($decision.warnings)
        action = $decision.action
        recommended_options = @(
            [ordered]@{ decision = 'recover'; required_field = 'replacement_path'; meaning = 'Use a recovered replacement file path after manual verification.' }
            [ordered]@{ decision = 'exception'; required_field = 'exception_reason'; meaning = 'Keep a documented missing-file exception for historical query only.' }
        )
    })
}

$readyItems = @($items.ToArray() | Where-Object { $_.status -eq 'ready' })
$pendingItems = @($items.ToArray() | Where-Object { $_.status -eq 'pending' })
$blockedDecisionItems = @($items.ToArray() | Where-Object { $_.status -eq 'blocked' })
$recoverItems = @($readyItems | Where-Object { $_.decision -eq 'recover' })
$exceptionItems = @($readyItems | Where-Object { $_.decision -eq 'exception' })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report isolates blocked attachment dry-run rows for business confirmation. It does not copy files or update CSV templates.'
    overall_status = if (-not $dryRun) { 'missing' } elseif ($blockedDecisionItems.Count -gt 0) { 'blocked' } elseif ($pendingItems.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_blocked_attachments = @($blockedItems).Count
        ready_decisions = $readyItems.Count
        pending_decisions = $pendingItems.Count
        blocked_decisions = $blockedDecisionItems.Count
        recover_decisions = $recoverItems.Count
        exception_decisions = $exceptionItems.Count
        exception_csv_rows = @($exceptionRows).Count
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy attachment exception confirmation written to $ReportPath"
