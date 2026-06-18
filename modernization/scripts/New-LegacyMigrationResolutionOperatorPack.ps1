param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-operator-pack.json"),
    [string]$ProgressPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-progress.json"),
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.json"),
    [string]$RowWorklistPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-row-worklist.json"),
    [string]$OwnerRowWorklistsPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-row-worklists.json"),
    [string]$OwnerTemplateRowWorklistsPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-template-row-worklists.json"),
    [string]$DistributionPackPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.json"),
    [string]$DistributionSignoffPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff.json"),
    [string]$DistributionSignoffValidationPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff-validation.json"),
    [string]$OwnerWorklistsPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-worklists.json"),
    [string]$ImportPreviewPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-import-preview.json"),
    [string]$ResolvedDryRunComparisonPath = (Join-Path $PSScriptRoot "legacy-migration-dry-run-comparison.json"),
    [string]$AcceptanceGatePath = (Join-Path $PSScriptRoot "legacy-migration-resolution-acceptance-gate.json"),
    [string]$AttachmentOperatorPackPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-operator-pack.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-Step($steps, $order, $title, $status, $action, $acceptance, $source) {
    $steps.Add([pscustomobject][ordered]@{
        order = $order
        title = $title
        status = $status
        action = $action
        acceptance = $acceptance
        source = $source
    })
}

function New-FileEntry($key, $path, $purpose) {
    return [ordered]@{
        key = $key
        path = $path
        purpose = $purpose
    }
}

$progress = Read-JsonReport $ProgressPath
$worklist = Read-JsonReport $WorklistPath
$rowWorklist = Read-JsonReport $RowWorklistPath
$ownerRowWorklists = Read-JsonReport $OwnerRowWorklistsPath
$ownerTemplateRowWorklists = Read-JsonReport $OwnerTemplateRowWorklistsPath
$distributionPack = Read-JsonReport $DistributionPackPath
$distributionSignoff = Read-JsonReport $DistributionSignoffPath
$distributionSignoffValidation = Read-JsonReport $DistributionSignoffValidationPath
$ownerWorklists = Read-JsonReport $OwnerWorklistsPath
$importPreview = Read-JsonReport $ImportPreviewPath
$comparison = Read-JsonReport $ResolvedDryRunComparisonPath
$acceptanceGate = Read-JsonReport $AcceptanceGatePath
$attachmentPack = Read-JsonReport $AttachmentOperatorPackPath

$steps = New-Object System.Collections.Generic.List[object]

$progressStatus = if ($progress) { $progress.overall_status } else { 'missing' }
Add-Step $steps 1 'Fill resolution CSV templates' $progressStatus 'Fill unit/user ids, project ids, attachment decisions, and approvals.' 'Resolution progress is 100% with no pending or blocked rows.' $ProgressPath

$worklistStatus = if ($worklist) { $worklist.overall_status } else { 'missing' }
Add-Step $steps 2 'Work through resolution task list' $worklistStatus 'Process worklist items by priority and owner.' 'No open worklist items remain.' $WorklistPath

$rowWorklistStatus = if ($rowWorklist) { $rowWorklist.overall_status } else { 'missing' }
Add-Step $steps 3 'Work through row-level resolution list' $rowWorklistStatus 'Use the row-level CSV to fill exact template rows.' 'No row-level work items remain.' $RowWorklistPath

$ownerRowWorklistsStatus = if ($ownerRowWorklists) { $ownerRowWorklists.overall_status } else { 'missing' }
Add-Step $steps 4 'Distribute owner row-level CSV files' $ownerRowWorklistsStatus 'Send owner row-level CSV files to reviewers and migration engineers.' 'Owner row-level CSV files have been processed and reflected in the source templates.' $OwnerRowWorklistsPath

$ownerTemplateRowWorklistsStatus = if ($ownerTemplateRowWorklists) { $ownerTemplateRowWorklists.overall_status } else { 'missing' }
Add-Step $steps 5 'Distribute owner template row-level CSV files' $ownerTemplateRowWorklistsStatus 'Use smaller owner-and-template CSV files for execution by workstream.' 'Owner template row-level CSV files have been processed and reflected in the source templates.' $OwnerTemplateRowWorklistsPath

$distributionPackStatus = if ($distributionPack) { $distributionPack.overall_status } else { 'missing' }
Add-Step $steps 6 'Package resolution distribution files' $distributionPackStatus 'Use the distribution manifest and ZIP to hand off CSV files.' 'Distribution pack has been reviewed and assigned to owners.' $DistributionPackPath

$distributionSignoffStatus = if ($distributionSignoff) { $distributionSignoff.overall_status } else { 'missing' }
Add-Step $steps 7 'Track distribution signoff' $distributionSignoffStatus 'Use the signoff CSV to track sent, accepted, and completed status.' 'All distribution signoff items are completed.' $DistributionSignoffPath

$distributionSignoffValidationStatus = if ($distributionSignoffValidation) { $distributionSignoffValidation.overall_status } else { 'missing' }
Add-Step $steps 8 'Validate distribution signoff fields' $distributionSignoffValidationStatus 'Review required manual fields for sent, accepted, completed, and blocked rows.' 'Signoff CSV has no blocker or warning validation issues.' $DistributionSignoffValidationPath

$ownerWorklistsStatus = if ($ownerWorklists) { $ownerWorklists.overall_status } else { 'missing' }
Add-Step $steps 9 'Distribute owner worklist CSV files' $ownerWorklistsStatus 'Send owner-specific CSV files to reviewers and migration engineers.' 'Each owner worklist has been processed and reflected in the source templates.' $OwnerWorklistsPath

$attachmentStatus = if ($attachmentPack) { $attachmentPack.overall_status } else { 'missing' }
Add-Step $steps 10 'Resolve missing attachment exceptions' $attachmentStatus 'Use the attachment operator pack to confirm recover or exception decisions.' 'Attachment exception pack is ready and patch rows are reviewed.' $AttachmentOperatorPackPath

$importStatus = if ($importPreview) { if ($importPreview.summary.ready_items -gt 0 -and $importPreview.summary.blocked_items -eq 0) { 'ready' } else { 'not_ready' } } else { 'missing' }
Add-Step $steps 11 'Preview resolved template imports' $importStatus 'Run import preview and verify ready rows before applying resolved maps.' 'Import preview has ready rows and no blocked rows.' $ImportPreviewPath

$comparisonStatus = if ($comparison) { $comparison.overall_status } else { 'missing' }
Add-Step $steps 12 'Compare default, resolved, and mock dry-runs' $comparisonStatus 'Review resolved readiness delta and remaining waiting or blocked records.' 'Resolved ready counts increase as mapping CSV rows are filled and approved.' $ResolvedDryRunComparisonPath

$acceptanceGateStatus = if ($acceptanceGate) { $acceptanceGate.overall_status } else { 'missing' }
Add-Step $steps 13 'Pass resolution acceptance gate' $acceptanceGateStatus 'Review the gate summary before migration rehearsal.' 'All acceptance gates pass with no blockers or warnings.' $AcceptanceGatePath

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'blocked' -or $_.status -eq 'missing' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' })
$readySteps = @($steps.ToArray() | Where-Object { $_.status -eq 'ready' })

$nextStep = $null
foreach ($step in @($steps.ToArray())) {
    if ($step.status -ne 'ready') {
        $nextStep = $step
        break
    }
}

$templateProgress = @()
if ($progress -and $progress.by_template) {
    $templateProgress = @($progress.by_template)
}

$topWorkItems = @()
if ($worklist -and $worklist.items) {
    $topWorkItems = @($worklist.items | Sort-Object -Property priority, template, field_group | Select-Object -First 10)
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This operator pack summarizes the resolution mapping workflow. It does not edit CSV files, copy files, update resolved maps, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_rows = if ($progress) { $progress.summary.total_rows } else { 0 }
        ready_rows = if ($progress) { $progress.summary.ready_rows } else { 0 }
        pending_rows = if ($progress) { $progress.summary.pending_rows } else { 0 }
        blocked_rows = if ($progress) { $progress.summary.blocked_rows } else { 0 }
        completion_percent = if ($progress) { $progress.summary.completion_percent } else { 0 }
        work_items = if ($worklist) { $worklist.summary.work_items } else { 0 }
        row_work_items = if ($rowWorklist) { $rowWorklist.summary.row_work_items } else { 0 }
        row_p1_items = if ($rowWorklist) { $rowWorklist.summary.p1_rows } else { 0 }
        owner_row_worklists = if ($ownerRowWorklists) { $ownerRowWorklists.summary.owner_count } else { 0 }
        owner_template_row_worklists = if ($ownerTemplateRowWorklists) { $ownerTemplateRowWorklists.summary.file_count } else { 0 }
        distribution_pack_files = if ($distributionPack) { $distributionPack.summary.file_count } else { 0 }
        distribution_pack_zip_exists = if ($distributionPack) { $distributionPack.summary.zip_exists } else { $false }
        distribution_signoff_items = if ($distributionSignoff) { $distributionSignoff.summary.signoff_items } else { 0 }
        distribution_signoff_pending = if ($distributionSignoff) { $distributionSignoff.summary.pending_items } else { 0 }
        signoff_validation_blockers = if ($distributionSignoffValidation) { $distributionSignoffValidation.summary.blockers } else { 0 }
        signoff_validation_warnings = if ($distributionSignoffValidation) { $distributionSignoffValidation.summary.warnings } else { 0 }
        owner_worklists = if ($ownerWorklists) { $ownerWorklists.summary.owner_count } else { 0 }
        p1_items = if ($worklist) { $worklist.summary.p1_items } else { 0 }
        import_ready_items = if ($importPreview) { $importPreview.summary.ready_items } else { 0 }
        import_pending_items = if ($importPreview) { $importPreview.summary.pending_items } else { 0 }
        import_blocked_items = if ($importPreview) { $importPreview.summary.blocked_items } else { 0 }
        resolved_ready_delta = if ($comparison) { $comparison.summary.resolved_ready_delta } else { 0 }
        total_resolved_waiting = if ($comparison) { $comparison.summary.total_resolved_waiting } else { 0 }
        total_resolved_blocked = if ($comparison) { $comparison.summary.total_resolved_blocked } else { 0 }
        acceptance_passed_gates = if ($acceptanceGate) { $acceptanceGate.summary.passed_gates } else { 0 }
        acceptance_open_gates = if ($acceptanceGate) { $acceptanceGate.summary.open_gates } else { 0 }
        acceptance_blockers = if ($acceptanceGate) { $acceptanceGate.summary.blockers } else { 0 }
        acceptance_warnings = if ($acceptanceGate) { $acceptanceGate.summary.warnings } else { 0 }
        acceptance_total_gates = if ($acceptanceGate) { $acceptanceGate.summary.total_gates } else { 0 }
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'resolution_worklist_csv' (Join-Path $PSScriptRoot 'legacy-migration-resolution-worklist.csv') 'assign resolution mapping tasks by priority and owner'
        New-FileEntry 'resolution_row_worklist' $RowWorklistPath 'row-level worklist for exact template updates'
        New-FileEntry 'resolution_row_worklist_csv' (Join-Path $PSScriptRoot 'legacy-migration-resolution-row-worklist.csv') 'row-level worklist CSV for exact template updates'
        New-FileEntry 'resolution_owner_row_worklists' $OwnerRowWorklistsPath 'owner-specific row-level resolution worklist manifest'
        New-FileEntry 'resolution_owner_template_row_worklists' $OwnerTemplateRowWorklistsPath 'owner-and-template row-level resolution worklist manifest'
        New-FileEntry 'resolution_distribution_pack' $DistributionPackPath 'distribution manifest and ZIP for owner-template row worklists'
        New-FileEntry 'resolution_distribution_pack_zip' (Join-Path $PSScriptRoot 'legacy-migration-resolution-distribution-pack.zip') 'ZIP package for owner-template row worklists'
        New-FileEntry 'resolution_distribution_signoff' $DistributionSignoffPath 'manual signoff tracking sheet for distribution handoff'
        New-FileEntry 'resolution_distribution_signoff_csv' (Join-Path $PSScriptRoot 'legacy-migration-resolution-distribution-signoff.csv') 'CSV signoff tracking sheet for distribution handoff'
        New-FileEntry 'resolution_distribution_signoff_validation' $DistributionSignoffValidationPath 'validation report for manual signoff status fields'
        New-FileEntry 'resolution_owner_worklists' $OwnerWorklistsPath 'owner-specific resolution worklist manifest'
        New-FileEntry 'resolution_acceptance_gate' $AcceptanceGatePath 'go/no-go gate for operator-filled resolution mappings'
        New-FileEntry 'resolution_acceptance_gate_csv' (Join-Path $PSScriptRoot 'legacy-migration-resolution-acceptance-gate.csv') 'CSV version of the resolution acceptance gate'
        New-FileEntry 'unit_user_template' (Join-Path $PSScriptRoot 'legacy-unit-user-id-map.template.csv') 'fill unit_id owner_id and approved_by'
        New-FileEntry 'project_template' (Join-Path $PSScriptRoot 'legacy-project-id-map.template.csv') 'fill new_project_id and approved_by'
        New-FileEntry 'attachment_exception_template' (Join-Path $PSScriptRoot 'legacy-attachment-exceptions.template.csv') 'fill attachment exception decisions and approvals'
        New-FileEntry 'attachment_operator_pack' $AttachmentOperatorPackPath 'missing attachment exception workflow'
    )
    template_progress = @($templateProgress)
    row_worklist_summary = if ($rowWorklist) { $rowWorklist.summary } else { $null }
    row_worklist_by_owner = if ($rowWorklist) { @($rowWorklist.by_owner) } else { @() }
    owner_row_worklists = if ($ownerRowWorklists) { @($ownerRowWorklists.files) } else { @() }
    owner_template_row_worklists = if ($ownerTemplateRowWorklists) { @($ownerTemplateRowWorklists.files) } else { @() }
    distribution_pack = if ($distributionPack) { $distributionPack } else { $null }
    distribution_signoff = if ($distributionSignoff) { $distributionSignoff } else { $null }
    distribution_signoff_validation = if ($distributionSignoffValidation) { $distributionSignoffValidation } else { $null }
    owner_worklists = if ($ownerWorklists) { @($ownerWorklists.files) } else { @() }
    acceptance_gates = if ($acceptanceGate) { @($acceptanceGate.gates) } else { @() }
    top_work_items = @($topWorkItems)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution operator pack written to $ReportPath"
