param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-gate.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-gate.csv"),
    [string]$ScriptsRoot = $PSScriptRoot
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

function Test-File($path) {
    return Test-Path -LiteralPath $path -PathType Leaf
}

$preflightPath = Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json'
$blockerSignoffPath = Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff.json'
$blockerSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff-validation.json'
$resolutionGatePath = Join-Path $ScriptsRoot 'legacy-migration-resolution-acceptance-gate.json'
$goLiveSignoffPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.json'
$goLiveSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-validation.json'
$samplingSignoffPath = Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff.json'
$samplingSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff-validation.json'
$orphanSignoffPath = Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff.json'
$orphanSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff-validation.json'
$manifestPath = Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json'
$goLiveDrillPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-report.md'
$rollbackPath = Join-Path $ScriptsRoot 'legacy-migration-rollback-plan.md'
$runbookPath = Join-Path $ScriptsRoot 'legacy-migration-operator-runbook.md'

$preflight = Read-JsonReport $preflightPath
$blockerSignoff = Read-JsonReport $blockerSignoffPath
$blockerSignoffValidation = Read-JsonReport $blockerSignoffValidationPath
$resolutionGate = Read-JsonReport $resolutionGatePath
$goLiveSignoff = Read-JsonReport $goLiveSignoffPath
$goLiveSignoffValidation = Read-JsonReport $goLiveSignoffValidationPath
$samplingSignoff = Read-JsonReport $samplingSignoffPath
$samplingSignoffValidation = Read-JsonReport $samplingSignoffValidationPath
$orphanSignoff = Read-JsonReport $orphanSignoffPath
$orphanSignoffValidation = Read-JsonReport $orphanSignoffValidationPath
$manifest = Read-JsonReport $manifestPath

$gates = New-Object System.Collections.Generic.List[object]

if (-not $preflight) {
    Add-Gate $gates 'preflight' 'Preflight checklist exists' 'missing' 'blocker' 'Preflight report is missing.' 'Run New-LegacyMigrationPreflightChecklist.ps1.' 'Preflight report exists with no blockers.' $preflightPath
} elseif ($preflight.summary.blockers -gt 0) {
    Add-Gate $gates 'preflight' 'Preflight has no blockers' 'blocked' 'blocker' "Blockers: $($preflight.summary.blockers), warnings: $($preflight.summary.warnings)." 'Resolve every blocker in the preflight checklist.' 'Blockers equal 0.' $preflightPath
} elseif ($preflight.summary.warnings -gt 0) {
    Add-Gate $gates 'preflight' 'Preflight warnings are accepted or cleared' 'open' 'warning' "Warnings: $($preflight.summary.warnings)." 'Clear warnings or record acceptance in go-live drill notes.' 'Warnings equal 0 or are signed off by owner.' $preflightPath
} else {
    Add-Gate $gates 'preflight' 'Preflight is clear' 'pass' 'info' 'No blockers or warnings.' 'No action.' 'Preflight is ready.' $preflightPath
}

if (-not $blockerSignoff) {
    Add-Gate $gates 'blocker_resolution_signoff' 'Blocker resolution signoff exists' 'missing' 'blocker' 'Blocker resolution signoff report is missing.' 'Run New-LegacyMigrationBlockerResolutionSignoff.ps1.' 'Signoff exists and all items are verified.' $blockerSignoffPath
} elseif ($blockerSignoff.summary.invalid_items -gt 0 -or $blockerSignoff.summary.blocked_items -gt 0) {
    Add-Gate $gates 'blocker_resolution_signoff' 'Blocker resolution signoff has no invalid or blocked items' 'blocked' 'blocker' "Invalid: $($blockerSignoff.summary.invalid_items), blocked: $($blockerSignoff.summary.blocked_items)." 'Fix invalid status rows or unblock blocked signoff items.' 'Invalid and blocked items equal 0.' $blockerSignoffPath
} elseif ($blockerSignoff.summary.verified_items -ne $blockerSignoff.summary.signoff_items) {
    Add-Gate $gates 'blocker_resolution_signoff' 'Blocker resolution signoff is fully verified' 'open' 'warning' "Pending: $($blockerSignoff.summary.pending_items), approved: $($blockerSignoff.summary.approved_items), executed: $($blockerSignoff.summary.executed_items), verified: $($blockerSignoff.summary.verified_items), total: $($blockerSignoff.summary.signoff_items)." 'Complete approval, execution, and verification for every blocked stage.' 'Verified items equal total signoff items.' $blockerSignoffPath
} else {
    Add-Gate $gates 'blocker_resolution_signoff' 'Blocker resolution signoff is fully verified' 'pass' 'info' "Verified items: $($blockerSignoff.summary.verified_items)." 'No action.' 'All blocker resolution items are verified.' $blockerSignoffPath
}

if (-not $blockerSignoffValidation) {
    Add-Gate $gates 'blocker_resolution_signoff_validation' 'Blocker signoff validation exists' 'missing' 'blocker' 'Blocker signoff validation report is missing.' 'Run Test-LegacyMigrationBlockerResolutionSignoff.ps1.' 'Validation report exists with zero blockers and zero warnings.' $blockerSignoffValidationPath
} elseif ($blockerSignoffValidation.summary.blockers -gt 0) {
    Add-Gate $gates 'blocker_resolution_signoff_validation' 'Blocker signoff validation has no blockers' 'blocked' 'blocker' "Blockers: $($blockerSignoffValidation.summary.blockers), warnings: $($blockerSignoffValidation.summary.warnings)." 'Fix invalid statuses or blocked rows without notes.' 'Validation blockers equal 0.' $blockerSignoffValidationPath
} elseif ($blockerSignoffValidation.summary.warnings -gt 0) {
    Add-Gate $gates 'blocker_resolution_signoff_validation' 'Blocker signoff validation warnings are cleared' 'open' 'warning' "Warnings: $($blockerSignoffValidation.summary.warnings)." 'Fill approval, execution, and verification audit fields.' 'Validation warnings equal 0.' $blockerSignoffValidationPath
} else {
    Add-Gate $gates 'blocker_resolution_signoff_validation' 'Blocker signoff validation is clean' 'pass' 'info' 'Blockers: 0, warnings: 0.' 'No action.' 'Validation is clean.' $blockerSignoffValidationPath
}

if (-not $resolutionGate) {
    Add-Gate $gates 'resolution_acceptance' 'Resolution acceptance gate exists' 'missing' 'blocker' 'Resolution acceptance gate is missing.' 'Run New-LegacyMigrationResolutionAcceptanceGate.ps1.' 'Resolution gate exists and is ready.' $resolutionGatePath
} elseif ($resolutionGate.summary.blockers -gt 0) {
    Add-Gate $gates 'resolution_acceptance' 'Resolution acceptance has no blockers' 'blocked' 'blocker' "Blockers: $($resolutionGate.summary.blockers), warnings: $($resolutionGate.summary.warnings)." 'Resolve the first failing resolution gate.' 'Resolution gate blockers equal 0.' $resolutionGatePath
} elseif ($resolutionGate.summary.warnings -gt 0) {
    Add-Gate $gates 'resolution_acceptance' 'Resolution acceptance warnings are cleared' 'open' 'warning' "Warnings: $($resolutionGate.summary.warnings), completion: $($resolutionGate.summary.completion_percent)%." 'Complete mapping templates, distribution signoff, and resolved dry-run readiness.' 'Resolution gate warnings equal 0.' $resolutionGatePath
} else {
    Add-Gate $gates 'resolution_acceptance' 'Resolution acceptance is ready' 'pass' 'info' "Passed gates: $($resolutionGate.summary.passed_gates)." 'No action.' 'Resolution acceptance gate is ready.' $resolutionGatePath
}

if (-not $manifest) {
    Add-Gate $gates 'artifact_manifest' 'Artifact manifest exists' 'missing' 'blocker' 'Artifact manifest is missing.' 'Run New-LegacyMigrationArtifactManifest.ps1.' 'Manifest exists with zero missing required artifacts.' $manifestPath
} elseif ($manifest.summary.missing_required -gt 0) {
    Add-Gate $gates 'artifact_manifest' 'Required artifacts are complete' 'blocked' 'blocker' "Missing required: $($manifest.summary.missing_required), missing optional: $($manifest.summary.missing_optional)." 'Regenerate missing required reports.' 'Missing required artifacts equal 0.' $manifestPath
} else {
    Add-Gate $gates 'artifact_manifest' 'Required artifacts are complete' 'pass' 'info' "Existing: $($manifest.summary.existing_artifacts), total: $($manifest.summary.total_artifacts), missing optional: $($manifest.summary.missing_optional)." 'No action.' 'Required artifacts are complete.' $manifestPath
}

if (-not $goLiveSignoff) {
    Add-Gate $gates 'go_live_signoff' 'Final go-live role signoff exists' 'missing' 'blocker' 'Go-live signoff report is missing.' 'Run New-LegacyMigrationGoLiveSignoff.ps1.' 'Signoff exists and every role is signed or accepted with risk.' $goLiveSignoffPath
} elseif ($goLiveSignoff.summary.invalid_items -gt 0 -or $goLiveSignoff.summary.rejected_items -gt 0) {
    Add-Gate $gates 'go_live_signoff' 'Final go-live signoff has no invalid or rejected roles' 'blocked' 'blocker' "Invalid: $($goLiveSignoff.summary.invalid_items), rejected: $($goLiveSignoff.summary.rejected_items)." 'Fix invalid statuses or resolve rejected role signoff.' 'Invalid and rejected items equal 0.' $goLiveSignoffPath
} elseif (($goLiveSignoff.summary.signed_items + $goLiveSignoff.summary.accepted_with_risk_items) -ne $goLiveSignoff.summary.signoff_items) {
    Add-Gate $gates 'go_live_signoff' 'Final go-live role signoff is complete' 'open' 'warning' "Pending: $($goLiveSignoff.summary.pending_items), signed: $($goLiveSignoff.summary.signed_items), accepted_with_risk: $($goLiveSignoff.summary.accepted_with_risk_items), total: $($goLiveSignoff.summary.signoff_items)." 'Collect technical, operations, business, and security signoff.' 'All roles are signed or accepted with risk.' $goLiveSignoffPath
} else {
    Add-Gate $gates 'go_live_signoff' 'Final go-live role signoff is complete' 'pass' 'info' "Signed: $($goLiveSignoff.summary.signed_items), accepted_with_risk: $($goLiveSignoff.summary.accepted_with_risk_items)." 'No action.' 'All roles have signed off.' $goLiveSignoffPath
}

if (-not $goLiveSignoffValidation) {
    Add-Gate $gates 'go_live_signoff_validation' 'Final go-live signoff validation exists' 'missing' 'blocker' 'Go-live signoff validation report is missing.' 'Run Test-LegacyMigrationGoLiveSignoff.ps1.' 'Validation report exists with zero blockers and zero warnings.' $goLiveSignoffValidationPath
} elseif ($goLiveSignoffValidation.summary.blockers -gt 0) {
    Add-Gate $gates 'go_live_signoff_validation' 'Final go-live signoff validation has no blockers' 'blocked' 'blocker' "Blockers: $($goLiveSignoffValidation.summary.blockers), warnings: $($goLiveSignoffValidation.summary.warnings)." 'Fix invalid or rejected signoff rows.' 'Validation blockers equal 0.' $goLiveSignoffValidationPath
} elseif ($goLiveSignoffValidation.summary.warnings -gt 0) {
    Add-Gate $gates 'go_live_signoff_validation' 'Final go-live signoff validation warnings are cleared' 'open' 'warning' "Warnings: $($goLiveSignoffValidation.summary.warnings)." 'Fill owner, signed_by, signed_at, and risk notes.' 'Validation warnings equal 0.' $goLiveSignoffValidationPath
} else {
    Add-Gate $gates 'go_live_signoff_validation' 'Final go-live signoff validation is clean' 'pass' 'info' 'Blockers: 0, warnings: 0.' 'No action.' 'Validation is clean.' $goLiveSignoffValidationPath
}

if (-not $samplingSignoff) {
    Add-Gate $gates 'sampling_acceptance_signoff' 'Business sampling acceptance signoff exists' 'missing' 'blocker' 'Sampling acceptance signoff report is missing.' 'Run New-LegacyMigrationSamplingAcceptanceSignoff.ps1.' 'Sampling signoff exists and all samples pass or are accepted with risk.' $samplingSignoffPath
} elseif ($samplingSignoff.summary.invalid_items -gt 0 -or $samplingSignoff.summary.failed_items -gt 0 -or $samplingSignoff.summary.blocked_items -gt 0) {
    Add-Gate $gates 'sampling_acceptance_signoff' 'Business sampling acceptance has no failed or blocked samples' 'blocked' 'blocker' "Invalid: $($samplingSignoff.summary.invalid_items), failed: $($samplingSignoff.summary.failed_items), blocked: $($samplingSignoff.summary.blocked_items)." 'Resolve failed or blocked sampling rows before go-live.' 'Invalid, failed, and blocked sample items equal 0.' $samplingSignoffPath
} elseif (($samplingSignoff.summary.passed_items + $samplingSignoff.summary.accepted_with_risk_items) -ne $samplingSignoff.summary.sample_items) {
    Add-Gate $gates 'sampling_acceptance_signoff' 'Business sampling acceptance is complete' 'open' 'warning' "Pending: $($samplingSignoff.summary.pending_items), passed: $($samplingSignoff.summary.passed_items), accepted_with_risk: $($samplingSignoff.summary.accepted_with_risk_items), total: $($samplingSignoff.summary.sample_items)." 'Complete unit, project, attachment, and workflow sampling checks.' 'Every sample is pass or accepted_with_risk.' $samplingSignoffPath
} else {
    Add-Gate $gates 'sampling_acceptance_signoff' 'Business sampling acceptance is complete' 'pass' 'info' "Passed: $($samplingSignoff.summary.passed_items), accepted_with_risk: $($samplingSignoff.summary.accepted_with_risk_items)." 'No action.' 'All sampling acceptance items are complete.' $samplingSignoffPath
}

if (-not $samplingSignoffValidation) {
    Add-Gate $gates 'sampling_acceptance_signoff_validation' 'Business sampling signoff validation exists' 'missing' 'blocker' 'Sampling signoff validation report is missing.' 'Run Test-LegacyMigrationSamplingAcceptanceSignoff.ps1.' 'Validation report exists with zero blockers and zero warnings.' $samplingSignoffValidationPath
} elseif ($samplingSignoffValidation.summary.blockers -gt 0) {
    Add-Gate $gates 'sampling_acceptance_signoff_validation' 'Business sampling signoff validation has no blockers' 'blocked' 'blocker' "Blockers: $($samplingSignoffValidation.summary.blockers), warnings: $($samplingSignoffValidation.summary.warnings)." 'Fix invalid, failed, or blocked sampling rows.' 'Validation blockers equal 0.' $samplingSignoffValidationPath
} elseif ($samplingSignoffValidation.summary.warnings -gt 0) {
    Add-Gate $gates 'sampling_acceptance_signoff_validation' 'Business sampling signoff validation warnings are cleared' 'open' 'warning' "Warnings: $($samplingSignoffValidation.summary.warnings)." 'Fill sampled_by, sampled_at, evidence_ref, and risk notes.' 'Validation warnings equal 0.' $samplingSignoffValidationPath
} else {
    Add-Gate $gates 'sampling_acceptance_signoff_validation' 'Business sampling signoff validation is clean' 'pass' 'info' 'Blockers: 0, warnings: 0.' 'No action.' 'Validation is clean.' $samplingSignoffValidationPath
}

if (-not $orphanSignoff) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff' 'Workflow orphan handling signoff exists' 'missing' 'blocker' 'Workflow orphan handling signoff report is missing.' 'Run New-LegacyWorkflowOrphanResolutionSignoff.ps1.' 'All orphan workflow rows have approved handling decisions.' $orphanSignoffPath
} elseif ($orphanSignoff.summary.invalid_items -gt 0 -or $orphanSignoff.summary.blocked_items -gt 0) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff' 'Workflow orphan handling has no invalid or blocked decisions' 'blocked' 'blocker' "Invalid: $($orphanSignoff.summary.invalid_items), blocked: $($orphanSignoff.summary.blocked_items)." 'Fix invalid decisions or unblock orphan workflow handling rows.' 'Invalid and blocked orphan workflow decisions equal 0.' $orphanSignoffPath
} elseif ($orphanSignoff.summary.pending_items -gt 0) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff' 'Workflow orphan handling decisions are complete' 'open' 'warning' "Pending: $($orphanSignoff.summary.pending_items), archive: $($orphanSignoff.summary.archive_items), link: $($orphanSignoff.summary.link_items), exclude: $($orphanSignoff.summary.exclude_items), total: $($orphanSignoff.summary.orphan_items)." 'Decide archive, link, or exclude for every orphan workflow row.' 'Every orphan workflow row has an approved handling decision.' $orphanSignoffPath
} else {
    Add-Gate $gates 'workflow_orphan_resolution_signoff' 'Workflow orphan handling decisions are complete' 'pass' 'info' "Archive: $($orphanSignoff.summary.archive_items), link: $($orphanSignoff.summary.link_items), exclude: $($orphanSignoff.summary.exclude_items)." 'No action.' 'All orphan workflow rows have handling decisions.' $orphanSignoffPath
}

if (-not $orphanSignoffValidation) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff_validation' 'Workflow orphan handling validation exists' 'missing' 'blocker' 'Workflow orphan handling validation report is missing.' 'Run Test-LegacyWorkflowOrphanResolutionSignoff.ps1.' 'Validation report exists with zero blockers and zero warnings.' $orphanSignoffValidationPath
} elseif ($orphanSignoffValidation.summary.blockers -gt 0) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff_validation' 'Workflow orphan handling validation has no blockers' 'blocked' 'blocker' "Blockers: $($orphanSignoffValidation.summary.blockers), warnings: $($orphanSignoffValidation.summary.warnings)." 'Fix invalid decisions, missing target links, or blocked rows.' 'Validation blockers equal 0.' $orphanSignoffValidationPath
} elseif ($orphanSignoffValidation.summary.warnings -gt 0) {
    Add-Gate $gates 'workflow_orphan_resolution_signoff_validation' 'Workflow orphan handling validation warnings are cleared' 'open' 'warning' "Warnings: $($orphanSignoffValidation.summary.warnings)." 'Fill approved_by, approved_at, evidence_ref, and notes where required.' 'Validation warnings equal 0.' $orphanSignoffValidationPath
} else {
    Add-Gate $gates 'workflow_orphan_resolution_signoff_validation' 'Workflow orphan handling validation is clean' 'pass' 'info' 'Blockers: 0, warnings: 0.' 'No action.' 'Validation is clean.' $orphanSignoffValidationPath
}

if (Test-File $goLiveDrillPath) {
    Add-Gate $gates 'go_live_drill_report' 'Go-live drill report exists' 'pass' 'info' 'Drill report file exists.' 'Fill manual sign-off fields before production window.' 'Drill report exists.' $goLiveDrillPath
} else {
    Add-Gate $gates 'go_live_drill_report' 'Go-live drill report exists' 'missing' 'blocker' 'Drill report file is missing.' 'Run New-LegacyMigrationGoLiveDrillReport.ps1.' 'Drill report exists.' $goLiveDrillPath
}

if (Test-File $rollbackPath) {
    Add-Gate $gates 'rollback_plan' 'Rollback plan exists' 'pass' 'info' 'Rollback plan file exists.' 'Review rollback triggers and owners before production window.' 'Rollback plan exists.' $rollbackPath
} else {
    Add-Gate $gates 'rollback_plan' 'Rollback plan exists' 'missing' 'blocker' 'Rollback plan file is missing.' 'Run New-LegacyMigrationRollbackPlan.ps1.' 'Rollback plan exists.' $rollbackPath
}

if (Test-File $runbookPath) {
    Add-Gate $gates 'operator_runbook' 'Operator runbook exists' 'pass' 'info' 'Operator runbook file exists.' 'Review runbook with technical owner.' 'Runbook exists.' $runbookPath
} else {
    Add-Gate $gates 'operator_runbook' 'Operator runbook exists' 'missing' 'blocker' 'Operator runbook file is missing.' 'Run New-LegacyMigrationOperatorRunbook.ps1.' 'Runbook exists.' $runbookPath
}

$blockers = @($gates.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($gates.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$passed = @($gates.ToArray() | Where-Object { $_.status -eq 'pass' }).Count
$open = @($gates.ToArray() | Where-Object { $_.status -eq 'open' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This gate summarizes go-live readiness. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    write_cutover_ready = ($blockers -eq 0 -and $warnings -eq 0)
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
Write-Host "Legacy migration go-live gate written to $ReportPath"
Write-Host "Legacy migration go-live gate CSV written to $CsvPath"
