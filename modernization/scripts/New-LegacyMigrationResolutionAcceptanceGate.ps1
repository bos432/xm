param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-acceptance-gate.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-acceptance-gate.csv"),
    [string]$ValidationPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-validation.json"),
    [string]$ProgressPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-progress.json"),
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.json"),
    [string]$OwnerWorklistsPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-worklists.json"),
    [string]$DistributionSignoffPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff.json"),
    [string]$ImportPreviewPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-import-preview.json"),
    [string]$DryRunComparisonPath = (Join-Path $PSScriptRoot "legacy-migration-dry-run-comparison.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-Gate($gates, $key, $title, $status, $severity, $evidence, $action, $acceptance, $source) {
    $gates.Add([pscustomobject][ordered]@{
        key = $key
        title = $title
        status = $status
        severity = $severity
        evidence = $evidence
        action = $action
        acceptance = $acceptance
        source = $source
    })
}

$validation = Read-JsonReport $ValidationPath
$progress = Read-JsonReport $ProgressPath
$worklist = Read-JsonReport $WorklistPath
$ownerWorklists = Read-JsonReport $OwnerWorklistsPath
$distributionSignoff = Read-JsonReport $DistributionSignoffPath
$importPreview = Read-JsonReport $ImportPreviewPath
$comparison = Read-JsonReport $DryRunComparisonPath

$gates = New-Object System.Collections.Generic.List[object]

if (-not $validation) {
    Add-Gate $gates 'template_validation' 'Template validation report exists' 'missing' 'blocker' 'Validation report is missing.' 'Run Test-LegacyMigrationResolutionTemplates.ps1.' 'Validation report exists with zero blockers.' $ValidationPath
} elseif ($validation.summary.blockers -gt 0) {
    Add-Gate $gates 'template_validation' 'Template validation has no blockers' 'blocked' 'blocker' "Blockers: $($validation.summary.blockers), warnings: $($validation.summary.warnings)." 'Fix invalid ids, duplicate mappings, and invalid attachment decisions.' 'Blockers equal 0.' $ValidationPath
} elseif ($validation.summary.warnings -gt 0) {
    Add-Gate $gates 'template_validation' 'Template validation warnings are cleared' 'open' 'warning' "Warnings: $($validation.summary.warnings)." 'Fill missing mappings, decisions, and approved_by values.' 'Warnings equal 0.' $ValidationPath
} else {
    Add-Gate $gates 'template_validation' 'Template validation is clean' 'pass' 'info' 'Blockers: 0, warnings: 0.' 'No action.' 'Validation is clean.' $ValidationPath
}

if (-not $progress) {
    Add-Gate $gates 'mapping_completion' 'Mapping templates are fully completed' 'missing' 'blocker' 'Progress report is missing.' 'Run New-LegacyMigrationResolutionProgress.ps1.' 'Ready rows equal total rows and blocked rows equal 0.' $ProgressPath
} elseif ($progress.summary.blocked_rows -gt 0) {
    Add-Gate $gates 'mapping_completion' 'Mapping templates have no blocked rows' 'blocked' 'blocker' "Blocked rows: $($progress.summary.blocked_rows), pending rows: $($progress.summary.pending_rows)." 'Fix invalid or partially filled CSV rows.' 'Blocked rows equal 0.' $ProgressPath
} elseif ($progress.summary.ready_rows -ne $progress.summary.total_rows) {
    Add-Gate $gates 'mapping_completion' 'Mapping templates are fully completed' 'open' 'warning' "Completion: $($progress.summary.completion_percent)%, ready: $($progress.summary.ready_rows), pending: $($progress.summary.pending_rows), total: $($progress.summary.total_rows)." 'Complete the unit/user, project, and attachment exception templates.' 'Completion is 100% and pending rows equal 0.' $ProgressPath
} else {
    Add-Gate $gates 'mapping_completion' 'Mapping templates are fully completed' 'pass' 'info' "Completion: $($progress.summary.completion_percent)%." 'No action.' 'Completion is 100%.' $ProgressPath
}

if (-not $worklist) {
    Add-Gate $gates 'worklist_clearance' 'Resolution worklist is cleared' 'missing' 'blocker' 'Worklist report is missing.' 'Run New-LegacyMigrationResolutionWorklist.ps1.' 'No open or blocked work items remain.' $WorklistPath
} elseif ($worklist.summary.blocked_items -gt 0) {
    Add-Gate $gates 'worklist_clearance' 'Resolution worklist has no blocked tasks' 'blocked' 'blocker' "Blocked items: $($worklist.summary.blocked_items), work items: $($worklist.summary.work_items)." 'Fix blocked work items first.' 'Blocked work items equal 0.' $WorklistPath
} elseif ($worklist.summary.work_items -gt 0) {
    Add-Gate $gates 'worklist_clearance' 'Resolution worklist is cleared' 'open' 'warning' "Open items: $($worklist.summary.work_items), P1 items: $($worklist.summary.p1_items)." 'Process all owner worklists and update the source templates.' 'Open work items equal 0.' $WorklistPath
} else {
    Add-Gate $gates 'worklist_clearance' 'Resolution worklist is cleared' 'pass' 'info' 'No open work items.' 'No action.' 'No open work items remain.' $WorklistPath
}

if (-not $ownerWorklists) {
    Add-Gate $gates 'owner_distribution' 'Owner worklist files are generated' 'missing' 'blocker' 'Owner worklist report is missing.' 'Run New-LegacyMigrationResolutionOwnerWorklists.ps1.' 'Owner worklist manifest exists.' $OwnerWorklistsPath
} elseif ($ownerWorklists.summary.blocked_items -gt 0) {
    Add-Gate $gates 'owner_distribution' 'Owner worklists have no blocked tasks' 'blocked' 'blocker' "Owner files: $($ownerWorklists.summary.owner_count), blocked items: $($ownerWorklists.summary.blocked_items)." 'Fix blocked owner worklist items.' 'Blocked owner items equal 0.' $OwnerWorklistsPath
} elseif ($ownerWorklists.summary.work_items -gt 0) {
    Add-Gate $gates 'owner_distribution' 'Owner worklists are processed' 'open' 'warning' "Owner files: $($ownerWorklists.summary.owner_count), work items: $($ownerWorklists.summary.work_items)." 'Distribute owner CSV files, complete review, then update source templates.' 'Owner work items equal 0.' $OwnerWorklistsPath
} else {
    Add-Gate $gates 'owner_distribution' 'Owner worklists are processed' 'pass' 'info' 'No owner work items remain.' 'No action.' 'Owner worklists are clear.' $OwnerWorklistsPath
}

if (-not $distributionSignoff) {
    Add-Gate $gates 'distribution_signoff' 'Distribution signoff is complete' 'missing' 'blocker' 'Distribution signoff report is missing.' 'Run New-LegacyMigrationResolutionDistributionSignoff.ps1.' 'Distribution signoff exists and all items are completed.' $DistributionSignoffPath
} elseif ($distributionSignoff.summary.invalid_items -gt 0) {
    Add-Gate $gates 'distribution_signoff' 'Distribution signoff has valid statuses' 'blocked' 'blocker' "Invalid items: $($distributionSignoff.summary.invalid_items)." 'Use only pending, sent, accepted, completed, or blocked status values.' 'Invalid items equal 0.' $DistributionSignoffPath
} elseif ($distributionSignoff.summary.blocked_items -gt 0) {
    Add-Gate $gates 'distribution_signoff' 'Distribution signoff has no blocked items' 'blocked' 'blocker' "Blocked items: $($distributionSignoff.summary.blocked_items)." 'Review blocked signoff notes and unblock the handoff.' 'Blocked signoff items equal 0.' $DistributionSignoffPath
} elseif ($distributionSignoff.summary.completed_items -ne $distributionSignoff.summary.signoff_items) {
    Add-Gate $gates 'distribution_signoff' 'Distribution signoff is complete' 'open' 'warning' "Pending: $($distributionSignoff.summary.pending_items), sent: $($distributionSignoff.summary.sent_items), accepted: $($distributionSignoff.summary.accepted_items), completed: $($distributionSignoff.summary.completed_items), total: $($distributionSignoff.summary.signoff_items)." 'Send, accept, complete, and record all distribution signoff items.' 'Completed signoff items equal total signoff items.' $DistributionSignoffPath
} else {
    Add-Gate $gates 'distribution_signoff' 'Distribution signoff is complete' 'pass' 'info' "Completed items: $($distributionSignoff.summary.completed_items)." 'No action.' 'All distribution signoff items are completed.' $DistributionSignoffPath
}

if (-not $importPreview) {
    Add-Gate $gates 'import_preview' 'Resolution import preview is ready' 'missing' 'blocker' 'Import preview report is missing.' 'Run New-LegacyMigrationResolutionImportPreview.ps1.' 'Preview exists with all rows ready and no blocked rows.' $ImportPreviewPath
} elseif ($importPreview.summary.blocked_items -gt 0) {
    Add-Gate $gates 'import_preview' 'Resolution import preview has no blocked rows' 'blocked' 'blocker' "Blocked items: $($importPreview.summary.blocked_items), pending items: $($importPreview.summary.pending_items)." 'Fix invalid or partially filled CSV rows.' 'Blocked preview items equal 0.' $ImportPreviewPath
} elseif ($importPreview.summary.ready_items -ne $importPreview.summary.total_items) {
    Add-Gate $gates 'import_preview' 'Resolution import preview is fully ready' 'open' 'warning' "Ready: $($importPreview.summary.ready_items), pending: $($importPreview.summary.pending_items), total: $($importPreview.summary.total_items)." 'Complete all templates and rerun the preview.' 'Ready items equal total items.' $ImportPreviewPath
} else {
    Add-Gate $gates 'import_preview' 'Resolution import preview is fully ready' 'pass' 'info' "Ready items: $($importPreview.summary.ready_items)." 'No action.' 'All preview rows are ready.' $ImportPreviewPath
}

if (-not $comparison) {
    Add-Gate $gates 'resolved_dry_run' 'Resolved dry-run comparison is available' 'missing' 'blocker' 'Dry-run comparison report is missing.' 'Run New-LegacyMigrationDryRunComparison.ps1.' 'Comparison report exists and resolved dry-run has no waiting or blocked records.' $DryRunComparisonPath
} elseif ($comparison.overall_status -ne 'ready') {
    Add-Gate $gates 'resolved_dry_run' 'Resolved dry-run comparison inputs are ready' 'blocked' 'blocker' "Comparison status: $($comparison.overall_status)." 'Generate all default, resolved, and mock dry-run inputs.' 'Comparison status is ready.' $DryRunComparisonPath
} elseif (($comparison.summary.total_resolved_waiting -gt 0) -or ($comparison.summary.total_resolved_blocked -gt 0)) {
    Add-Gate $gates 'resolved_dry_run' 'Resolved dry-run has no waiting or blocked records' 'open' 'warning' "Resolved waiting: $($comparison.summary.total_resolved_waiting), resolved blocked: $($comparison.summary.total_resolved_blocked), ready delta: $($comparison.summary.resolved_ready_delta)." 'Complete mappings and rerun resolved dry-run reports.' 'Resolved waiting and blocked counts equal 0.' $DryRunComparisonPath
} else {
    Add-Gate $gates 'resolved_dry_run' 'Resolved dry-run has no waiting or blocked records' 'pass' 'info' "Resolved ready delta: $($comparison.summary.resolved_ready_delta)." 'No action.' 'Resolved dry-run is fully clear.' $DryRunComparisonPath
}

$blockers = @($gates.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($gates.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$passed = @($gates.ToArray() | Where-Object { $_.status -eq 'pass' }).Count
$open = @($gates.ToArray() | Where-Object { $_.status -eq 'open' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This gate summarizes whether operator-filled resolution CSV templates are ready for resolved import preview and migration rehearsal. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_gates = $gates.Count
        passed_gates = $passed
        open_gates = $open
        blockers = $blockers
        warnings = $warnings
        completion_percent = if ($gates.Count -eq 0) { 0 } else { [math]::Round(($passed / $gates.Count) * 100, 2) }
    }
    next_step = @($gates.ToArray() | Where-Object { $_.status -ne 'pass' } | Select-Object -First 1)
    gates = @($gates.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
@($gates.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation
Write-Host "Legacy migration resolution acceptance gate written to $ReportPath"
Write-Host "Legacy migration resolution acceptance gate CSV written to $CsvPath"
