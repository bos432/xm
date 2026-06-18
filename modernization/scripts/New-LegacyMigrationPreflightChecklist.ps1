param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-checklist.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-ChecklistItem($items, $category, $severity, $title, $source, $status, $action) {
    $items.Add([pscustomobject][ordered]@{
        category = $category
        severity = $severity
        title = $title
        source = $source
        status = $status
        action = $action
    })
}

function Join-Text($values) {
    $items = @($values | Where-Object { $_ })
    if ($items.Count -eq 0) { return '-' }
    return ($items -join ', ')
}

function Get-FirstItem($value) {
    if ($null -eq $value) { return $null }
    if ($value -is [array]) {
        if ($value.Count -eq 0) { return $null }
        return $value[0]
    }
    return $value
}

function Get-NextTitle($value) {
    $item = Get-FirstItem $value
    if ($null -eq $item) { return '-' }
    if ($item.PSObject.Properties.Name -contains 'title') {
        return [string]$item.title
    }
    return '-'
}

$readiness = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-readiness-summary.json')
$batchPlan = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-batch-plan.json')
$manifest = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json')
$resolutionValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-validation.json')
$resolutionProgress = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-progress.json')
$resolutionWorklist = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-worklist.json')
$resolutionRowWorklist = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-row-worklist.json')
$resolutionOwnerRowWorklists = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-owner-row-worklists.json')
$resolutionOwnerTemplateRowWorklists = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-owner-template-row-worklists.json')
$resolutionDistributionPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-distribution-pack.json')
$resolutionDistributionSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-distribution-signoff.json')
$resolutionDistributionSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-distribution-signoff-validation.json')
$resolutionImportPreview = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-import-preview.json')
$resolutionAcceptanceGate = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-acceptance-gate.json')
$unitUserResolvedMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-id-map.resolved.json')
$projectResolvedMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-id-map.resolved.json')
$attachmentExceptionsResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exceptions.resolved.json')
$unitUserDbResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.resolved.json')
$projectDbResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.resolved.json')
$projectFileDbResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.resolved.json')
$dryRunComparison = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-dry-run-comparison.json')
$resolutionOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack.json')
$blockerResolutionPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-pack.json')
$blockerResolutionSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff.json')
$blockerResolutionSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff-validation.json')
$blockerResolutionOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack.json')
$samplingSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff.json')
$samplingSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff-validation.json')
$samplingOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack.json')
$orphanSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff.json')
$orphanSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff-validation.json')
$orphanOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack.json')
$attachmentDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-dry-run.json')
$attachmentExceptionConfirmation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-confirmation.json')
$attachmentExceptionWorksheet = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-worksheet.json')
$attachmentExceptionWorksheetImportPreview = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-worksheet-import-preview.json')
$attachmentExceptionTemplatePatchPreview = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-template-patch-preview.json')
$attachmentExceptionOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-operator-pack.json')
$projectDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.mock.json')
$projectFileDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.mock.json')
$unitUserDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.mock.json')
$workflowDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-db-dry-run.json')
$workflowDryRunMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-db-dry-run.mock.json')
$goLiveSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.json')
$goLiveSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-validation.json')
$goLiveSignoffOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack.json')
$goLiveDrillOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack.json')
$securityBaselineOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack.json')
$securityBaselineSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.json')
$securityBaselineSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff-validation.json')

$items = New-Object System.Collections.Generic.List[object]

if (-not $readiness) {
    Add-ChecklistItem $items 'reports' 'blocker' 'Generate readiness summary' 'legacy-migration-readiness-summary.json' 'open' 'Run New-LegacyMigrationReadinessSummary.ps1.'
} else {
    foreach ($gate in @($readiness.gates)) {
        if ($gate.status -eq 'blocked' -or $gate.status -eq 'missing') {
            Add-ChecklistItem $items 'readiness' 'blocker' "Resolve readiness blocker: $($gate.key)" $gate.key 'open' (Join-Text $gate.warnings)
        } elseif ($gate.status -eq 'waiting' -or $gate.status -eq 'warning') {
            Add-ChecklistItem $items 'readiness' 'warning' "Resolve readiness warning: $($gate.key)" $gate.key 'open' (Join-Text $gate.warnings)
        }
    }
}

if (-not $batchPlan) {
    Add-ChecklistItem $items 'reports' 'blocker' 'Generate migration batch plan' 'legacy-migration-batch-plan.json' 'open' 'Run New-LegacyMigrationBatchPlan.ps1.'
} else {
    foreach ($stage in @($batchPlan.stages)) {
        if ($stage.status -eq 'blocked' -or $stage.status -eq 'missing') {
            Add-ChecklistItem $items 'batch' 'blocker' "Batch stage blocked: $($stage.key)" $stage.key 'open' (Join-Text $stage.warnings)
        } elseif ($stage.status -eq 'waiting') {
            Add-ChecklistItem $items 'batch' 'warning' "Batch stage waiting: $($stage.key)" $stage.key 'open' ('Dependencies: ' + (Join-Text $stage.dependencies))
        }
    }
}

if (-not $manifest) {
    Add-ChecklistItem $items 'reports' 'blocker' 'Generate artifact manifest' 'legacy-migration-artifact-manifest.json' 'open' 'Run New-LegacyMigrationArtifactManifest.ps1.'
} else {
    foreach ($key in @($manifest.missing_required)) {
        Add-ChecklistItem $items 'artifacts' 'blocker' "Required artifact missing: $key" 'artifact_manifest' 'open' 'Run the full report pipeline or the matching script.'
    }
    foreach ($key in @($manifest.missing_optional)) {
        Add-ChecklistItem $items 'artifacts' 'info' "Optional artifact missing: $key" 'artifact_manifest' 'optional' 'Generate only when needed; mock and execute reports may be optional.'
    }
}

if (-not $blockerResolutionPack) {
    Add-ChecklistItem $items 'blocker_resolution_pack' 'blocker' 'Generate blocker resolution pack' 'legacy-migration-blocker-resolution-pack.json' 'open' 'Run New-LegacyMigrationBlockerResolutionPack.ps1.'
} else {
    Add-ChecklistItem $items 'blocker_resolution_pack' 'info' 'Blocker resolution pack is available' 'legacy-migration-blocker-resolution-pack.json' 'done' "Blocked stages documented: $($blockerResolutionPack.summary.blocked_stages)."
}

if (-not $blockerResolutionSignoff) {
    Add-ChecklistItem $items 'blocker_resolution_signoff' 'blocker' 'Generate blocker resolution signoff sheet' 'legacy-migration-blocker-resolution-signoff.json' 'open' 'Run New-LegacyMigrationBlockerResolutionSignoff.ps1.'
} elseif ($blockerResolutionSignoff.summary.invalid_items -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_signoff' 'blocker' 'Fix invalid blocker resolution signoff statuses' 'legacy-migration-blocker-resolution-signoff.csv' 'open' "Invalid status rows: $($blockerResolutionSignoff.summary.invalid_items). Use pending, approved, executed, verified, or blocked."
} elseif ($blockerResolutionSignoff.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_signoff' 'blocker' 'Resolve blocked blocker-resolution signoff items' 'legacy-migration-blocker-resolution-signoff.csv' 'open' "Blocked signoff items: $($blockerResolutionSignoff.summary.blocked_items). Review notes and unblock the resolution plan."
} elseif ($blockerResolutionSignoff.summary.verified_items -eq $blockerResolutionSignoff.summary.signoff_items) {
    Add-ChecklistItem $items 'blocker_resolution_signoff' 'info' 'Blocker resolution signoff is verified' 'legacy-migration-blocker-resolution-signoff.json' 'done' "Verified signoff items: $($blockerResolutionSignoff.summary.verified_items)."
} else {
    Add-ChecklistItem $items 'blocker_resolution_signoff' 'warning' 'Complete blocker resolution signoff' 'legacy-migration-blocker-resolution-signoff.csv' 'open' "Pending: $($blockerResolutionSignoff.summary.pending_items), approved: $($blockerResolutionSignoff.summary.approved_items), executed: $($blockerResolutionSignoff.summary.executed_items), verified: $($blockerResolutionSignoff.summary.verified_items)."
}

if (-not $blockerResolutionSignoffValidation) {
    Add-ChecklistItem $items 'blocker_resolution_signoff_validation' 'blocker' 'Validate blocker resolution signoff fields' 'legacy-migration-blocker-resolution-signoff-validation.json' 'open' 'Run Test-LegacyMigrationBlockerResolutionSignoff.ps1.'
} elseif ($blockerResolutionSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_signoff_validation' 'blocker' 'Fix blocker resolution signoff validation blockers' 'legacy-migration-blocker-resolution-signoff.csv' 'open' "Blockers: $($blockerResolutionSignoffValidation.summary.blockers). Fix invalid statuses or blocked rows without notes."
} elseif ($blockerResolutionSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_signoff_validation' 'warning' 'Complete blocker resolution signoff audit fields' 'legacy-migration-blocker-resolution-signoff.csv' 'open' "Warnings: $($blockerResolutionSignoffValidation.summary.warnings). Fill approval, execution, and verification fields for advanced statuses."
} else {
    Add-ChecklistItem $items 'blocker_resolution_signoff_validation' 'info' 'Blocker resolution signoff fields are valid' 'legacy-migration-blocker-resolution-signoff-validation.json' 'done' "Validated rows: $($blockerResolutionSignoffValidation.summary.signoff_rows)."
}

if (-not $blockerResolutionOperatorPack) {
    Add-ChecklistItem $items 'blocker_resolution_operator_pack' 'blocker' 'Generate blocker resolution operator pack' 'legacy-migration-blocker-resolution-operator-pack.json' 'open' 'Run New-LegacyMigrationBlockerResolutionOperatorPack.ps1.'
} elseif ($blockerResolutionOperatorPack.summary.validation_blockers -gt 0 -or $blockerResolutionOperatorPack.summary.invalid_items -gt 0 -or $blockerResolutionOperatorPack.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_operator_pack' 'blocker' 'Fix blocker resolution operator pack blockers' 'legacy-migration-blocker-resolution-operator-pack.json' 'open' "Validation blockers: $($blockerResolutionOperatorPack.summary.validation_blockers), invalid: $($blockerResolutionOperatorPack.summary.invalid_items), blocked: $($blockerResolutionOperatorPack.summary.blocked_items)."
} elseif ($blockerResolutionOperatorPack.summary.pending_items -gt 0 -or $blockerResolutionOperatorPack.summary.approved_items -gt 0 -or $blockerResolutionOperatorPack.summary.executed_items -gt 0 -or $blockerResolutionOperatorPack.summary.validation_warnings -gt 0) {
    Add-ChecklistItem $items 'blocker_resolution_operator_pack' 'warning' 'Use blocker resolution operator pack for approval execution verification' 'legacy-migration-blocker-resolution-operator-pack.json' 'open' "Pending: $($blockerResolutionOperatorPack.summary.pending_items), approved: $($blockerResolutionOperatorPack.summary.approved_items), executed: $($blockerResolutionOperatorPack.summary.executed_items), verified: $($blockerResolutionOperatorPack.summary.verified_items)."
} else {
    Add-ChecklistItem $items 'blocker_resolution_operator_pack' 'info' 'Blocker resolution operator pack is complete' 'legacy-migration-blocker-resolution-operator-pack.json' 'done' "Verified signoff items: $($blockerResolutionOperatorPack.summary.verified_items)."
}

if (-not $resolutionValidation) {
    Add-ChecklistItem $items 'resolution_templates' 'blocker' 'Validate resolution templates' 'legacy-migration-resolution-validation.json' 'open' 'Run Test-LegacyMigrationResolutionTemplates.ps1.'
} elseif ($resolutionValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'resolution_templates' 'blocker' 'Resolve template validation blockers' 'legacy-migration-resolution-validation.json' 'open' "Blockers: $($resolutionValidation.summary.blockers). Fix invalid ids, duplicate mappings, or invalid decisions."
} elseif ($resolutionValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'resolution_templates' 'warning' 'Complete pending template values' 'legacy-migration-resolution-validation.json' 'open' "Warnings: $($resolutionValidation.summary.warnings). Fill mappings, decisions, and approvals before production import."
} else {
    Add-ChecklistItem $items 'resolution_templates' 'info' 'Resolution templates validated' 'legacy-migration-resolution-validation.json' 'done' 'All required mapping and exception templates are ready.'
}

if (-not $samplingSignoff) {
    Add-ChecklistItem $items 'sampling_acceptance' 'blocker' 'Generate business sampling acceptance signoff sheet' 'legacy-migration-sampling-acceptance-signoff.json' 'open' 'Run New-LegacyMigrationSamplingAcceptanceSignoff.ps1.'
} elseif ($samplingSignoff.summary.invalid_items -gt 0 -or $samplingSignoff.summary.failed_items -gt 0 -or $samplingSignoff.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'sampling_acceptance' 'blocker' 'Resolve failed or blocked business sampling items' 'legacy-migration-sampling-acceptance-signoff.csv' 'open' "Invalid: $($samplingSignoff.summary.invalid_items), failed: $($samplingSignoff.summary.failed_items), blocked: $($samplingSignoff.summary.blocked_items)."
} elseif (($samplingSignoff.summary.passed_items + $samplingSignoff.summary.accepted_with_risk_items) -ne $samplingSignoff.summary.sample_items) {
    Add-ChecklistItem $items 'sampling_acceptance' 'warning' 'Complete business sampling acceptance signoff' 'legacy-migration-sampling-acceptance-signoff.csv' 'open' "Pending: $($samplingSignoff.summary.pending_items), passed: $($samplingSignoff.summary.passed_items), accepted_with_risk: $($samplingSignoff.summary.accepted_with_risk_items), total: $($samplingSignoff.summary.sample_items)."
} else {
    Add-ChecklistItem $items 'sampling_acceptance' 'info' 'Business sampling acceptance signoff is complete' 'legacy-migration-sampling-acceptance-signoff.json' 'done' "Passed: $($samplingSignoff.summary.passed_items), accepted_with_risk: $($samplingSignoff.summary.accepted_with_risk_items)."
}

if (-not $samplingSignoffValidation) {
    Add-ChecklistItem $items 'sampling_acceptance_validation' 'blocker' 'Validate business sampling acceptance fields' 'legacy-migration-sampling-acceptance-signoff-validation.json' 'open' 'Run Test-LegacyMigrationSamplingAcceptanceSignoff.ps1.'
} elseif ($samplingSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'sampling_acceptance_validation' 'blocker' 'Fix business sampling acceptance validation blockers' 'legacy-migration-sampling-acceptance-signoff.csv' 'open' "Blockers: $($samplingSignoffValidation.summary.blockers). Fix invalid, failed, or blocked sampling rows."
} elseif ($samplingSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'sampling_acceptance_validation' 'warning' 'Complete business sampling acceptance audit fields' 'legacy-migration-sampling-acceptance-signoff.csv' 'open' "Warnings: $($samplingSignoffValidation.summary.warnings). Fill sampled_by, sampled_at, evidence_ref, and risk notes for reviewed samples."
} else {
    Add-ChecklistItem $items 'sampling_acceptance_validation' 'info' 'Business sampling acceptance fields are valid' 'legacy-migration-sampling-acceptance-signoff-validation.json' 'done' "Validated rows: $($samplingSignoffValidation.summary.sample_rows)."
}

if (-not $samplingOperatorPack) {
    Add-ChecklistItem $items 'sampling_acceptance_operator_pack' 'blocker' 'Generate business sampling acceptance operator pack' 'legacy-migration-sampling-acceptance-operator-pack.json' 'open' 'Run New-LegacyMigrationSamplingAcceptanceOperatorPack.ps1.'
} elseif ($samplingOperatorPack.summary.validation_blockers -gt 0 -or $samplingOperatorPack.summary.failed_items -gt 0 -or $samplingOperatorPack.summary.blocked_items -gt 0 -or $samplingOperatorPack.summary.invalid_items -gt 0) {
    Add-ChecklistItem $items 'sampling_acceptance_operator_pack' 'blocker' 'Fix business sampling acceptance operator pack blockers' 'legacy-migration-sampling-acceptance-operator-pack.json' 'open' "Validation blockers: $($samplingOperatorPack.summary.validation_blockers), failed: $($samplingOperatorPack.summary.failed_items), blocked: $($samplingOperatorPack.summary.blocked_items), invalid: $($samplingOperatorPack.summary.invalid_items)."
} elseif ($samplingOperatorPack.summary.pending_items -gt 0 -or $samplingOperatorPack.summary.validation_warnings -gt 0) {
    Add-ChecklistItem $items 'sampling_acceptance_operator_pack' 'warning' 'Use business sampling acceptance operator pack' 'legacy-migration-sampling-acceptance-operator-pack.json' 'open' "Pending samples: $($samplingOperatorPack.summary.pending_items), categories: $($samplingOperatorPack.summary.category_count)."
} else {
    Add-ChecklistItem $items 'sampling_acceptance_operator_pack' 'info' 'Business sampling acceptance operator pack is complete' 'legacy-migration-sampling-acceptance-operator-pack.json' 'done' "Accepted samples: $($samplingOperatorPack.summary.passed_items + $samplingOperatorPack.summary.accepted_with_risk_items)."
}

if (-not $goLiveSignoff) {
    Add-ChecklistItem $items 'go_live_signoff' 'blocker' 'Generate final go-live role signoff sheet' 'legacy-migration-go-live-signoff.json' 'open' 'Run New-LegacyMigrationGoLiveSignoff.ps1.'
} elseif ($goLiveSignoff.summary.invalid_items -gt 0 -or $goLiveSignoff.summary.rejected_items -gt 0) {
    Add-ChecklistItem $items 'go_live_signoff' 'blocker' 'Resolve invalid or rejected go-live role signoff' 'legacy-migration-go-live-signoff.csv' 'open' "Invalid: $($goLiveSignoff.summary.invalid_items), rejected: $($goLiveSignoff.summary.rejected_items)."
} elseif (($goLiveSignoff.summary.signed_items + $goLiveSignoff.summary.accepted_with_risk_items) -ne $goLiveSignoff.summary.signoff_items) {
    Add-ChecklistItem $items 'go_live_signoff' 'warning' 'Complete final go-live role signoff' 'legacy-migration-go-live-signoff.csv' 'open' "Pending: $($goLiveSignoff.summary.pending_items), signed: $($goLiveSignoff.summary.signed_items), accepted_with_risk: $($goLiveSignoff.summary.accepted_with_risk_items), total: $($goLiveSignoff.summary.signoff_items)."
} else {
    Add-ChecklistItem $items 'go_live_signoff' 'info' 'Final go-live role signoff is complete' 'legacy-migration-go-live-signoff.json' 'done' "Signed: $($goLiveSignoff.summary.signed_items), accepted_with_risk: $($goLiveSignoff.summary.accepted_with_risk_items)."
}

if (-not $goLiveSignoffValidation) {
    Add-ChecklistItem $items 'go_live_signoff_validation' 'blocker' 'Validate final go-live role signoff fields' 'legacy-migration-go-live-signoff-validation.json' 'open' 'Run Test-LegacyMigrationGoLiveSignoff.ps1.'
} elseif ($goLiveSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'go_live_signoff_validation' 'blocker' 'Fix final go-live signoff validation blockers' 'legacy-migration-go-live-signoff.csv' 'open' "Blockers: $($goLiveSignoffValidation.summary.blockers). Fix invalid or rejected signoff rows."
} elseif ($goLiveSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'go_live_signoff_validation' 'warning' 'Complete final go-live signoff audit fields' 'legacy-migration-go-live-signoff.csv' 'open' "Warnings: $($goLiveSignoffValidation.summary.warnings). Fill owner, signed_by, signed_at, and risk notes."
} else {
    Add-ChecklistItem $items 'go_live_signoff_validation' 'info' 'Final go-live signoff fields are valid' 'legacy-migration-go-live-signoff-validation.json' 'done' "Validated rows: $($goLiveSignoffValidation.summary.signoff_rows)."
}

if (-not $goLiveSignoffOperatorPack) {
    Add-ChecklistItem $items 'go_live_signoff_operator_pack' 'blocker' 'Generate final go-live signoff operator pack' 'legacy-migration-go-live-signoff-operator-pack.json' 'open' 'Run New-LegacyMigrationGoLiveSignoffOperatorPack.ps1.'
} elseif ($goLiveSignoffOperatorPack.summary.validation_blockers -gt 0 -or $goLiveSignoffOperatorPack.summary.rejected_items -gt 0 -or $goLiveSignoffOperatorPack.summary.invalid_items -gt 0) {
    Add-ChecklistItem $items 'go_live_signoff_operator_pack' 'blocker' 'Fix final go-live signoff operator pack blockers' 'legacy-migration-go-live-signoff-operator-pack.json' 'open' "Validation blockers: $($goLiveSignoffOperatorPack.summary.validation_blockers), rejected: $($goLiveSignoffOperatorPack.summary.rejected_items), invalid: $($goLiveSignoffOperatorPack.summary.invalid_items)."
} elseif ($goLiveSignoffOperatorPack.summary.pending_items -gt 0 -or $goLiveSignoffOperatorPack.summary.validation_warnings -gt 0) {
    Add-ChecklistItem $items 'go_live_signoff_operator_pack' 'warning' 'Use final go-live signoff operator pack' 'legacy-migration-go-live-signoff-operator-pack.json' 'open' "Pending roles: $($goLiveSignoffOperatorPack.summary.pending_items), signed: $($goLiveSignoffOperatorPack.summary.signed_items), accepted_with_risk: $($goLiveSignoffOperatorPack.summary.accepted_with_risk_items)."
} else {
    Add-ChecklistItem $items 'go_live_signoff_operator_pack' 'info' 'Final go-live signoff operator pack is complete' 'legacy-migration-go-live-signoff-operator-pack.json' 'done' "Signed: $($goLiveSignoffOperatorPack.summary.signed_items), accepted_with_risk: $($goLiveSignoffOperatorPack.summary.accepted_with_risk_items)."
}

if (-not $securityBaselineOperatorPack) {
    Add-ChecklistItem $items 'security_baseline_operator_pack' 'blocker' 'Generate security baseline operator pack' 'legacy-security-baseline-operator-pack.json' 'open' 'Run New-LegacySecurityBaselineOperatorPack.ps1.'
} elseif ($securityBaselineOperatorPack.summary.blocked_steps -gt 0) {
    Add-ChecklistItem $items 'security_baseline_operator_pack' 'blocker' 'Fix security baseline blockers' 'legacy-security-baseline-operator-pack.json' 'open' ("Blocked steps: " + $securityBaselineOperatorPack.summary.blocked_steps + ", executable public files: " + $securityBaselineOperatorPack.summary.executable_public_files + ", dangerous attachments: " + $securityBaselineOperatorPack.summary.attachment_dangerous_extensions + ".")
} elseif ($securityBaselineOperatorPack.summary.pending_steps -gt 0 -or $securityBaselineOperatorPack.overall_status -ne 'ready') {
    Add-ChecklistItem $items 'security_baseline_operator_pack' 'warning' 'Use security baseline operator pack' 'legacy-security-baseline-operator-pack.json' 'open' ("Pending steps: " + $securityBaselineOperatorPack.summary.pending_steps + ", dangerous PHP patterns: " + $securityBaselineOperatorPack.summary.dangerous_php_patterns + ", missing attachments: " + $securityBaselineOperatorPack.summary.attachment_missing_files + ".")
} else {
    Add-ChecklistItem $items 'security_baseline_operator_pack' 'info' 'Security baseline operator pack is complete' 'legacy-security-baseline-operator-pack.json' 'done' 'All security baseline operator steps are ready.'
}

if (-not $securityBaselineSignoff) {
    Add-ChecklistItem $items 'security_baseline_signoff' 'blocker' 'Generate security baseline signoff sheet' 'legacy-security-baseline-signoff.json' 'open' 'Run New-LegacySecurityBaselineSignoff.ps1.'
} elseif ($securityBaselineSignoff.summary.blocked_items -gt 0 -or $securityBaselineSignoff.summary.invalid_items -gt 0) {
    Add-ChecklistItem $items 'security_baseline_signoff' 'blocker' 'Fix security baseline signoff blocked or invalid items' 'legacy-security-baseline-signoff.csv' 'open' ("Blocked: " + $securityBaselineSignoff.summary.blocked_items + ", invalid: " + $securityBaselineSignoff.summary.invalid_items + ".")
} elseif (($securityBaselineSignoff.summary.mitigated_items + $securityBaselineSignoff.summary.accepted_with_risk_items) -ne $securityBaselineSignoff.summary.signoff_items) {
    Add-ChecklistItem $items 'security_baseline_signoff' 'warning' 'Complete security baseline signoff' 'legacy-security-baseline-signoff.csv' 'open' ("Pending: " + $securityBaselineSignoff.summary.pending_items + ", mitigated: " + $securityBaselineSignoff.summary.mitigated_items + ", risk accepted: " + $securityBaselineSignoff.summary.accepted_with_risk_items + ".")
} else {
    Add-ChecklistItem $items 'security_baseline_signoff' 'info' 'Security baseline signoff is complete' 'legacy-security-baseline-signoff.json' 'done' ("Mitigated: " + $securityBaselineSignoff.summary.mitigated_items + ", risk accepted: " + $securityBaselineSignoff.summary.accepted_with_risk_items + ".")
}

if (-not $securityBaselineSignoffValidation) {
    Add-ChecklistItem $items 'security_baseline_signoff_validation' 'blocker' 'Validate security baseline signoff fields' 'legacy-security-baseline-signoff-validation.json' 'open' 'Run Test-LegacySecurityBaselineSignoff.ps1.'
} elseif ($securityBaselineSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'security_baseline_signoff_validation' 'blocker' 'Fix security baseline signoff validation blockers' 'legacy-security-baseline-signoff.csv' 'open' ("Blockers: " + $securityBaselineSignoffValidation.summary.blockers + ".")
} elseif ($securityBaselineSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'security_baseline_signoff_validation' 'warning' 'Complete security baseline signoff audit fields' 'legacy-security-baseline-signoff.csv' 'open' ("Warnings: " + $securityBaselineSignoffValidation.summary.warnings + ". Fill owner, resolved_by, resolved_at, evidence_ref, and risk notes.")
} else {
    Add-ChecklistItem $items 'security_baseline_signoff_validation' 'info' 'Security baseline signoff fields are valid' 'legacy-security-baseline-signoff-validation.json' 'done' ("Validated rows: " + $securityBaselineSignoffValidation.summary.signoff_rows + ".")
}

if (-not $goLiveDrillOperatorPack) {
    Add-ChecklistItem $items 'go_live_drill_operator_pack' 'blocker' 'Generate go-live drill operator pack' 'legacy-migration-go-live-drill-operator-pack.json' 'open' 'Run New-LegacyMigrationGoLiveDrillOperatorPack.ps1.'
} elseif ($goLiveDrillOperatorPack.summary.blocked_steps -gt 0) {
    Add-ChecklistItem $items 'go_live_drill_operator_pack' 'blocker' 'Fix go-live drill operator pack blockers' 'legacy-migration-go-live-drill-operator-pack.json' 'open' "Blocked steps: $($goLiveDrillOperatorPack.summary.blocked_steps), preflight blockers: $($goLiveDrillOperatorPack.summary.preflight_blockers)."
} elseif ($goLiveDrillOperatorPack.summary.pending_steps -gt 0) {
    Add-ChecklistItem $items 'go_live_drill_operator_pack' 'warning' 'Use go-live drill operator pack' 'legacy-migration-go-live-drill-operator-pack.json' 'open' "Pending steps: $($goLiveDrillOperatorPack.summary.pending_steps), next: $(Get-NextTitle $goLiveDrillOperatorPack.next_step)."
} else {
    Add-ChecklistItem $items 'go_live_drill_operator_pack' 'info' 'Go-live drill operator pack is complete' 'legacy-migration-go-live-drill-operator-pack.json' 'done' 'All drill operator steps are ready.'
}

if (-not $orphanSignoff) {
    Add-ChecklistItem $items 'workflow_orphan_resolution' 'blocker' 'Generate workflow orphan handling signoff sheet' 'legacy-workflow-orphan-resolution-signoff.json' 'open' 'Run New-LegacyWorkflowOrphanResolutionSignoff.ps1.'
} elseif ($orphanSignoff.summary.invalid_items -gt 0 -or $orphanSignoff.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_resolution' 'blocker' 'Resolve invalid or blocked workflow orphan decisions' 'legacy-workflow-orphan-resolution-signoff.csv' 'open' "Invalid: $($orphanSignoff.summary.invalid_items), blocked: $($orphanSignoff.summary.blocked_items)."
} elseif ($orphanSignoff.summary.pending_items -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_resolution' 'warning' 'Complete workflow orphan handling decisions' 'legacy-workflow-orphan-resolution-signoff.csv' 'open' "Pending: $($orphanSignoff.summary.pending_items), archive: $($orphanSignoff.summary.archive_items), link: $($orphanSignoff.summary.link_items), exclude: $($orphanSignoff.summary.exclude_items)."
} else {
    Add-ChecklistItem $items 'workflow_orphan_resolution' 'info' 'Workflow orphan handling decisions are complete' 'legacy-workflow-orphan-resolution-signoff.json' 'done' "Archive: $($orphanSignoff.summary.archive_items), link: $($orphanSignoff.summary.link_items), exclude: $($orphanSignoff.summary.exclude_items)."
}

if (-not $orphanSignoffValidation) {
    Add-ChecklistItem $items 'workflow_orphan_resolution_validation' 'blocker' 'Validate workflow orphan handling fields' 'legacy-workflow-orphan-resolution-signoff-validation.json' 'open' 'Run Test-LegacyWorkflowOrphanResolutionSignoff.ps1.'
} elseif ($orphanSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_resolution_validation' 'blocker' 'Fix workflow orphan handling validation blockers' 'legacy-workflow-orphan-resolution-signoff.csv' 'open' "Blockers: $($orphanSignoffValidation.summary.blockers). Fix invalid decisions, missing target links, or blocked rows."
} elseif ($orphanSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_resolution_validation' 'warning' 'Complete workflow orphan handling audit fields' 'legacy-workflow-orphan-resolution-signoff.csv' 'open' "Warnings: $($orphanSignoffValidation.summary.warnings). Fill approvals, evidence, and notes for decided rows."
} else {
    Add-ChecklistItem $items 'workflow_orphan_resolution_validation' 'info' 'Workflow orphan handling fields are valid' 'legacy-workflow-orphan-resolution-signoff-validation.json' 'done' "Validated rows: $($orphanSignoffValidation.summary.orphan_rows)."
}

if (-not $orphanOperatorPack) {
    Add-ChecklistItem $items 'workflow_orphan_operator_pack' 'blocker' 'Generate workflow orphan operator pack' 'legacy-workflow-orphan-operator-pack.json' 'open' 'Run New-LegacyWorkflowOrphanOperatorPack.ps1.'
} elseif ($orphanOperatorPack.summary.validation_blockers -gt 0 -or $orphanOperatorPack.summary.invalid_items -gt 0 -or $orphanOperatorPack.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_operator_pack' 'blocker' 'Fix workflow orphan operator pack blockers' 'legacy-workflow-orphan-operator-pack.json' 'open' "Validation blockers: $($orphanOperatorPack.summary.validation_blockers), invalid: $($orphanOperatorPack.summary.invalid_items), blocked: $($orphanOperatorPack.summary.blocked_items)."
} elseif ($orphanOperatorPack.summary.pending_items -gt 0 -or $orphanOperatorPack.summary.validation_warnings -gt 0) {
    Add-ChecklistItem $items 'workflow_orphan_operator_pack' 'warning' 'Use workflow orphan operator pack for business decisions' 'legacy-workflow-orphan-operator-pack.json' 'open' "Pending decisions: $($orphanOperatorPack.summary.pending_items), legacy projects: $($orphanOperatorPack.summary.legacy_project_count)."
} else {
    Add-ChecklistItem $items 'workflow_orphan_operator_pack' 'info' 'Workflow orphan operator pack is complete' 'legacy-workflow-orphan-operator-pack.json' 'done' "Decided orphan rows: $($orphanOperatorPack.summary.decided_items)."
}

if (-not $resolutionProgress) {
    Add-ChecklistItem $items 'resolution_progress' 'blocker' 'Generate resolution progress report' 'legacy-migration-resolution-progress.json' 'open' 'Run New-LegacyMigrationResolutionProgress.ps1.'
} elseif ($resolutionProgress.summary.blocked_rows -gt 0) {
    Add-ChecklistItem $items 'resolution_progress' 'blocker' 'Fix blocked resolution CSV rows' 'legacy-migration-resolution-progress.json' 'open' "Blocked rows: $($resolutionProgress.summary.blocked_rows). Fix invalid or partially filled mapping rows."
} elseif ($resolutionProgress.summary.ready_rows -eq $resolutionProgress.summary.total_rows) {
    Add-ChecklistItem $items 'resolution_progress' 'info' 'Resolution CSV progress is complete' 'legacy-migration-resolution-progress.json' 'done' "Completion: $($resolutionProgress.summary.completion_percent)%."
} else {
    Add-ChecklistItem $items 'resolution_progress' 'warning' 'Complete resolution CSV mappings' 'legacy-migration-resolution-progress.json' 'open' "Completion: $($resolutionProgress.summary.completion_percent)%, pending rows: $($resolutionProgress.summary.pending_rows)."
}

if (-not $resolutionWorklist) {
    Add-ChecklistItem $items 'resolution_worklist' 'blocker' 'Generate resolution worklist report' 'legacy-migration-resolution-worklist.json' 'open' 'Run New-LegacyMigrationResolutionWorklist.ps1.'
} elseif ($resolutionWorklist.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'resolution_worklist' 'blocker' 'Resolve blocked resolution work items' 'legacy-migration-resolution-worklist.json' 'open' "Blocked work items: $($resolutionWorklist.summary.blocked_items). Fix invalid CSV values first."
} elseif ($resolutionWorklist.summary.work_items -gt 0) {
    Add-ChecklistItem $items 'resolution_worklist' 'warning' 'Finish resolution worklist items' 'legacy-migration-resolution-worklist.json' 'open' "Open work items: $($resolutionWorklist.summary.work_items), P1 items: $($resolutionWorklist.summary.p1_items)."
} else {
    Add-ChecklistItem $items 'resolution_worklist' 'info' 'Resolution worklist is complete' 'legacy-migration-resolution-worklist.json' 'done' 'No open CSV mapping work items remain.'
}

if (-not $resolutionRowWorklist) {
    Add-ChecklistItem $items 'resolution_row_worklist' 'blocker' 'Generate row-level resolution worklist' 'legacy-migration-resolution-row-worklist.json' 'open' 'Run New-LegacyMigrationResolutionRowWorklist.ps1.'
} elseif ($resolutionRowWorklist.summary.blocked_rows -gt 0) {
    Add-ChecklistItem $items 'resolution_row_worklist' 'blocker' 'Resolve blocked row-level resolution items' 'legacy-migration-resolution-row-worklist.json' 'open' "Blocked rows: $($resolutionRowWorklist.summary.blocked_rows). Fix invalid or partially filled CSV values first."
} elseif ($resolutionRowWorklist.summary.row_work_items -gt 0) {
    Add-ChecklistItem $items 'resolution_row_worklist' 'warning' 'Finish row-level resolution worklist' 'legacy-migration-resolution-row-worklist.csv' 'open' "Open row items: $($resolutionRowWorklist.summary.row_work_items), P1 rows: $($resolutionRowWorklist.summary.p1_rows)."
} else {
    Add-ChecklistItem $items 'resolution_row_worklist' 'info' 'Row-level resolution worklist is complete' 'legacy-migration-resolution-row-worklist.json' 'done' 'No open row-level mapping work items remain.'
}

if (-not $resolutionOwnerRowWorklists) {
    Add-ChecklistItem $items 'resolution_owner_row_worklists' 'blocker' 'Generate owner row-level resolution worklists' 'legacy-migration-resolution-owner-row-worklists.json' 'open' 'Run New-LegacyMigrationResolutionOwnerRowWorklists.ps1.'
} elseif ($resolutionOwnerRowWorklists.summary.blocked_rows -gt 0) {
    Add-ChecklistItem $items 'resolution_owner_row_worklists' 'blocker' 'Resolve blocked owner row-level items' 'legacy-migration-resolution-owner-row-worklists.json' 'open' "Blocked rows: $($resolutionOwnerRowWorklists.summary.blocked_rows). Fix invalid or partially filled CSV values first."
} elseif ($resolutionOwnerRowWorklists.summary.row_work_items -gt 0) {
    Add-ChecklistItem $items 'resolution_owner_row_worklists' 'warning' 'Distribute owner row-level resolution CSV files' 'legacy-migration-resolution-owner-row-worklists.json' 'open' "Owner files: $($resolutionOwnerRowWorklists.summary.owner_count), row items: $($resolutionOwnerRowWorklists.summary.row_work_items)."
} else {
    Add-ChecklistItem $items 'resolution_owner_row_worklists' 'info' 'Owner row-level resolution worklists are complete' 'legacy-migration-resolution-owner-row-worklists.json' 'done' 'No open owner row-level mapping work items remain.'
}

if (-not $resolutionOwnerTemplateRowWorklists) {
    Add-ChecklistItem $items 'resolution_owner_template_row_worklists' 'blocker' 'Generate owner template row-level worklists' 'legacy-migration-resolution-owner-template-row-worklists.json' 'open' 'Run New-LegacyMigrationResolutionOwnerTemplateRowWorklists.ps1.'
} elseif ($resolutionOwnerTemplateRowWorklists.summary.blocked_rows -gt 0) {
    Add-ChecklistItem $items 'resolution_owner_template_row_worklists' 'blocker' 'Resolve blocked owner template row-level items' 'legacy-migration-resolution-owner-template-row-worklists.json' 'open' "Blocked rows: $($resolutionOwnerTemplateRowWorklists.summary.blocked_rows). Fix invalid or partially filled CSV values first."
} elseif ($resolutionOwnerTemplateRowWorklists.summary.row_work_items -gt 0) {
    Add-ChecklistItem $items 'resolution_owner_template_row_worklists' 'warning' 'Distribute owner template row-level CSV files' 'legacy-migration-resolution-owner-template-row-worklists.json' 'open' "Files: $($resolutionOwnerTemplateRowWorklists.summary.file_count), row items: $($resolutionOwnerTemplateRowWorklists.summary.row_work_items)."
} else {
    Add-ChecklistItem $items 'resolution_owner_template_row_worklists' 'info' 'Owner template row-level worklists are complete' 'legacy-migration-resolution-owner-template-row-worklists.json' 'done' 'No open owner template row-level mapping work items remain.'
}

if (-not $resolutionDistributionPack) {
    Add-ChecklistItem $items 'resolution_distribution_pack' 'blocker' 'Generate resolution distribution pack' 'legacy-migration-resolution-distribution-pack.json' 'open' 'Run New-LegacyMigrationResolutionDistributionPack.ps1.'
} elseif ($resolutionDistributionPack.summary.missing_files -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_pack' 'blocker' 'Fix missing distribution pack files' 'legacy-migration-resolution-distribution-pack.json' 'open' "Missing files: $($resolutionDistributionPack.summary.missing_files). Regenerate owner-template row worklists."
} elseif (-not $resolutionDistributionPack.summary.zip_exists) {
    Add-ChecklistItem $items 'resolution_distribution_pack' 'blocker' 'Create resolution distribution ZIP' 'legacy-migration-resolution-distribution-pack.zip' 'open' 'Regenerate the distribution pack and confirm the ZIP exists.'
} elseif ($resolutionDistributionPack.summary.row_work_items -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_pack' 'warning' 'Hand off resolution distribution pack' 'legacy-migration-resolution-distribution-pack.zip' 'open' "Pack files: $($resolutionDistributionPack.summary.file_count), row items: $($resolutionDistributionPack.summary.row_work_items)."
} else {
    Add-ChecklistItem $items 'resolution_distribution_pack' 'info' 'Resolution distribution pack is complete' 'legacy-migration-resolution-distribution-pack.json' 'done' 'No open distribution pack row items remain.'
}

if (-not $resolutionDistributionSignoff) {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'blocker' 'Generate resolution distribution signoff sheet' 'legacy-migration-resolution-distribution-signoff.json' 'open' 'Run New-LegacyMigrationResolutionDistributionSignoff.ps1.'
} elseif ($resolutionDistributionSignoff.summary.invalid_items -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'blocker' 'Fix invalid resolution distribution signoff statuses' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Invalid status rows: $($resolutionDistributionSignoff.summary.invalid_items). Use pending, sent, accepted, completed, or blocked."
} elseif ($resolutionDistributionSignoff.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'blocker' 'Resolve blocked resolution distribution signoff items' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Blocked signoff items: $($resolutionDistributionSignoff.summary.blocked_items). Review notes and unblock the handoff."
} elseif ($resolutionDistributionSignoff.summary.pending_items -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'warning' 'Complete resolution distribution signoff' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Pending signoff items: $($resolutionDistributionSignoff.summary.pending_items), row items: $($resolutionDistributionSignoff.summary.row_work_items)."
} elseif (($resolutionDistributionSignoff.summary.sent_items -gt 0) -or ($resolutionDistributionSignoff.summary.accepted_items -gt 0)) {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'warning' 'Complete accepted resolution distribution work' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Sent: $($resolutionDistributionSignoff.summary.sent_items), accepted: $($resolutionDistributionSignoff.summary.accepted_items), completed: $($resolutionDistributionSignoff.summary.completed_items)."
} else {
    Add-ChecklistItem $items 'resolution_distribution_signoff' 'info' 'Resolution distribution signoff is complete' 'legacy-migration-resolution-distribution-signoff.json' 'done' 'All distribution signoff items are completed.'
}

if (-not $resolutionDistributionSignoffValidation) {
    Add-ChecklistItem $items 'resolution_distribution_signoff_validation' 'blocker' 'Validate resolution distribution signoff fields' 'legacy-migration-resolution-distribution-signoff-validation.json' 'open' 'Run Test-LegacyMigrationResolutionDistributionSignoff.ps1.'
} elseif ($resolutionDistributionSignoffValidation.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_signoff_validation' 'blocker' 'Fix blocked distribution signoff fields' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Blockers: $($resolutionDistributionSignoffValidation.summary.blockers). Fix invalid status rows or blocked rows without notes."
} elseif ($resolutionDistributionSignoffValidation.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'resolution_distribution_signoff_validation' 'warning' 'Complete distribution signoff audit fields' 'legacy-migration-resolution-distribution-signoff.csv' 'open' "Warnings: $($resolutionDistributionSignoffValidation.summary.warnings). Fill recipient, sent, accepted, and completed fields for advanced statuses."
} else {
    Add-ChecklistItem $items 'resolution_distribution_signoff_validation' 'info' 'Distribution signoff fields are valid' 'legacy-migration-resolution-distribution-signoff-validation.json' 'done' "Validated rows: $($resolutionDistributionSignoffValidation.summary.signoff_rows)."
}

if (-not $resolutionImportPreview) {
    Add-ChecklistItem $items 'resolution_import_preview' 'blocker' 'Preview resolved template imports' 'legacy-migration-resolution-import-preview.json' 'open' 'Run New-LegacyMigrationResolutionImportPreview.ps1.'
} elseif ($resolutionImportPreview.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'resolution_import_preview' 'blocker' 'Fix blocked resolved template imports' 'legacy-migration-resolution-import-preview.json' 'open' "Blocked preview rows: $($resolutionImportPreview.summary.blocked_items). Fix partially filled or invalid CSV rows."
} elseif ($resolutionImportPreview.summary.ready_items -eq 0) {
    Add-ChecklistItem $items 'resolution_import_preview' 'warning' 'Fill resolution templates for import preview' 'legacy-migration-resolution-import-preview.json' 'open' 'No ready template rows are available for mapping import preview.'
} else {
    Add-ChecklistItem $items 'resolution_import_preview' 'info' 'Resolution import preview has ready rows' 'legacy-migration-resolution-import-preview.json' 'done' "Ready rows: $($resolutionImportPreview.summary.ready_items)."
}

if (-not $resolutionAcceptanceGate) {
    Add-ChecklistItem $items 'resolution_acceptance_gate' 'blocker' 'Generate resolution acceptance gate' 'legacy-migration-resolution-acceptance-gate.json' 'open' 'Run New-LegacyMigrationResolutionAcceptanceGate.ps1.'
} elseif ($resolutionAcceptanceGate.summary.blockers -gt 0) {
    Add-ChecklistItem $items 'resolution_acceptance_gate' 'blocker' 'Resolve acceptance gate blockers' 'legacy-migration-resolution-acceptance-gate.json' 'open' "Blockers: $($resolutionAcceptanceGate.summary.blockers). Review the first failing gate: $(Get-NextTitle $resolutionAcceptanceGate.next_step)."
} elseif ($resolutionAcceptanceGate.summary.warnings -gt 0) {
    Add-ChecklistItem $items 'resolution_acceptance_gate' 'warning' 'Pass resolution acceptance gate' 'legacy-migration-resolution-acceptance-gate.json' 'open' "Warnings: $($resolutionAcceptanceGate.summary.warnings), completion: $($resolutionAcceptanceGate.summary.completion_percent)%. Next: $(Get-NextTitle $resolutionAcceptanceGate.next_step)."
} else {
    Add-ChecklistItem $items 'resolution_acceptance_gate' 'info' 'Resolution acceptance gate passed' 'legacy-migration-resolution-acceptance-gate.json' 'done' 'All resolution acceptance gates passed.'
}

if (-not $unitUserResolvedMap -or -not $projectResolvedMap -or -not $attachmentExceptionsResolved) {
    Add-ChecklistItem $items 'resolved_mapping_reports' 'blocker' 'Generate resolved mapping reports' 'resolved_mapping_reports' 'open' 'Run New-LegacyResolvedMappingReports.ps1.'
} elseif (($unitUserResolvedMap.summary.blocked_units -gt 0) -or ($projectResolvedMap.summary.blocked_projects -gt 0) -or ($attachmentExceptionsResolved.summary.blocked_exceptions -gt 0)) {
    Add-ChecklistItem $items 'resolved_mapping_reports' 'blocker' 'Fix blocked resolved mapping rows' 'resolved_mapping_reports' 'open' 'Resolved mapping previews contain blocked rows.'
} elseif (($unitUserResolvedMap.summary.mapped_units -gt 0) -or ($projectResolvedMap.summary.mapped_projects -gt 0) -or ($attachmentExceptionsResolved.summary.ready_exceptions -gt 0)) {
    Add-ChecklistItem $items 'resolved_mapping_reports' 'info' 'Resolved mapping reports are generated' 'resolved_mapping_reports' 'done' "units=$($unitUserResolvedMap.summary.mapped_units), projects=$($projectResolvedMap.summary.mapped_projects), attachment_exceptions=$($attachmentExceptionsResolved.summary.ready_exceptions)."
} else {
    Add-ChecklistItem $items 'resolved_mapping_reports' 'warning' 'No resolved mapping rows yet' 'resolved_mapping_reports' 'open' 'Operator templates are still empty; fill and approve CSV rows before applying resolved maps.'
}

if (-not $unitUserDbResolved -or -not $projectDbResolved -or -not $projectFileDbResolved) {
    Add-ChecklistItem $items 'resolved_mapping_dry_run' 'blocker' 'Generate resolved mapping dry-run reports' 'resolved_mapping_dry_run' 'open' 'Run Invoke-LegacyResolvedMappingDryRun.ps1.'
} elseif (($projectFileDbResolved.summary.ready_for_import -gt 0) -or ($projectDbResolved.summary.ready_for_import -gt 0) -or ($unitUserDbResolved.summary.ready_users -gt 0)) {
    Add-ChecklistItem $items 'resolved_mapping_dry_run' 'info' 'Resolved mapping dry-run reports are available' 'resolved_mapping_dry_run' 'done' "users_ready=$($unitUserDbResolved.summary.ready_users), projects_ready=$($projectDbResolved.summary.ready_for_import), files_ready=$($projectFileDbResolved.summary.ready_for_import)."
} else {
    Add-ChecklistItem $items 'resolved_mapping_dry_run' 'warning' 'Resolved mapping dry-run has no mapped records yet' 'resolved_mapping_dry_run' 'open' 'Fill and approve mapping CSV rows to move records into ready status.'
}

if (-not $dryRunComparison) {
    Add-ChecklistItem $items 'dry_run_comparison' 'blocker' 'Generate dry-run comparison report' 'legacy-migration-dry-run-comparison.json' 'open' 'Run New-LegacyMigrationDryRunComparison.ps1.'
} elseif ($dryRunComparison.overall_status -ne 'ready') {
    Add-ChecklistItem $items 'dry_run_comparison' 'blocker' 'Resolve dry-run comparison inputs' 'legacy-migration-dry-run-comparison.json' 'open' "Missing inputs: $($dryRunComparison.summary.missing_inputs)."
} else {
    Add-ChecklistItem $items 'dry_run_comparison' 'info' 'Dry-run comparison report is available' 'legacy-migration-dry-run-comparison.json' 'done' "resolved_ready_delta=$($dryRunComparison.summary.resolved_ready_delta), mock_ready_delta=$($dryRunComparison.summary.mock_ready_delta)."
}

if (-not $workflowDryRun) {
    Add-ChecklistItem $items 'workflow_dry_run' 'blocker' 'Generate workflow row-level dry-run report' 'legacy-workflow-db-dry-run.json' 'open' 'Run New-LegacyWorkflowDbDryRun.ps1.'
} elseif ($workflowDryRun.summary.review_records -eq 0 -and $workflowDryRun.summary.operation_log_records -eq 0) {
    Add-ChecklistItem $items 'workflow_dry_run' 'warning' 'Review workflow dry-run empty result' 'legacy-workflow-db-dry-run.json' 'open' 'No review or operation log rows were parsed from the SQL dump.'
} elseif ($workflowDryRun.summary.project_id_mapping_required -gt 0) {
    Add-ChecklistItem $items 'workflow_dry_run' 'warning' 'Resolve workflow project mappings' 'legacy-workflow-db-dry-run.json' 'open' "Review rows needing project mapping: $($workflowDryRun.summary.project_id_mapping_required), reviewer mapping warnings: $($workflowDryRun.summary.reviewer_id_mapping_required)."
} elseif ($workflowDryRun.summary.orphan_project_references -gt 0) {
    Add-ChecklistItem $items 'workflow_dry_run' 'warning' 'Review orphan workflow project references' 'legacy-workflow-db-dry-run.json' 'open' "Workflow rows reference missing legacy projects: $($workflowDryRun.summary.orphan_project_references). Decide whether to archive, link manually, or exclude with approval."
} else {
    Add-ChecklistItem $items 'workflow_dry_run' 'info' 'Workflow row-level dry-run is available' 'legacy-workflow-db-dry-run.json' 'done' "Reviews: $($workflowDryRun.summary.review_records), operation_logs: $($workflowDryRun.summary.operation_log_records)."
}

if ($workflowDryRunMock) {
    Add-ChecklistItem $items 'workflow_mock_validation' 'info' 'Mock workflow dry-run is available' 'legacy-workflow-db-dry-run.mock.json' 'done' "mock review project mappings pending=$($workflowDryRunMock.summary.project_id_mapping_required), operation_logs=$($workflowDryRunMock.summary.operation_log_records)."
}

if (-not $resolutionOperatorPack) {
    Add-ChecklistItem $items 'resolution_operator_pack' 'blocker' 'Generate resolution operator pack' 'legacy-migration-resolution-operator-pack.json' 'open' 'Run New-LegacyMigrationResolutionOperatorPack.ps1.'
} elseif ($resolutionOperatorPack.overall_status -ne 'ready') {
    Add-ChecklistItem $items 'resolution_operator_pack' 'warning' 'Follow resolution operator pack next step' 'legacy-migration-resolution-operator-pack.json' 'open' "Next: $(Get-NextTitle $resolutionOperatorPack.next_step)."
} else {
    Add-ChecklistItem $items 'resolution_operator_pack' 'info' 'Resolution operator pack is ready' 'legacy-migration-resolution-operator-pack.json' 'done' 'Resolution mapping workflow is ready.'
}

if ($attachmentDryRun -and $attachmentDryRun.summary.blocked_items -gt 0) {
    Add-ChecklistItem $items 'attachments' 'warning' 'Resolve missing attachments' 'legacy-attachment-import-dry-run.json' 'open' "Blocked attachments: $($attachmentDryRun.summary.blocked_items). Confirm file recovery or exception handling."
}

if (-not $attachmentExceptionConfirmation) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Generate attachment exception confirmation report' 'legacy-attachment-exception-confirmation.json' 'open' 'Run New-LegacyAttachmentExceptionConfirmation.ps1.'
} elseif ($attachmentExceptionConfirmation.summary.blocked_decisions -gt 0) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Fix blocked attachment exception decisions' 'legacy-attachment-exception-confirmation.json' 'open' "Blocked decisions: $($attachmentExceptionConfirmation.summary.blocked_decisions). Fix invalid or partially filled exception rows."
} elseif ($attachmentExceptionConfirmation.summary.pending_decisions -gt 0) {
    Add-ChecklistItem $items 'attachments' 'warning' 'Confirm missing attachment decisions' 'legacy-attachment-exception-confirmation.json' 'open' "Pending decisions: $($attachmentExceptionConfirmation.summary.pending_decisions). Choose recover or exception, then approve."
} else {
    Add-ChecklistItem $items 'attachments' 'info' 'Attachment exception decisions are complete' 'legacy-attachment-exception-confirmation.json' 'done' "Ready decisions: $($attachmentExceptionConfirmation.summary.ready_decisions)."
}

if (-not $attachmentExceptionWorksheet) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Generate attachment exception worksheet' 'legacy-attachment-exception-worksheet.json' 'open' 'Run New-LegacyAttachmentExceptionWorksheet.ps1.'
} elseif ($attachmentExceptionWorksheet.summary.pending_rows -gt 0) {
    Add-ChecklistItem $items 'attachments' 'warning' 'Use attachment exception worksheet for business confirmation' 'legacy-attachment-exception-worksheet.csv' 'open' "Worksheet rows: $($attachmentExceptionWorksheet.summary.worksheet_rows), pending rows: $($attachmentExceptionWorksheet.summary.pending_rows)."
} else {
    Add-ChecklistItem $items 'attachments' 'info' 'Attachment exception worksheet is complete' 'legacy-attachment-exception-worksheet.json' 'done' "Worksheet rows: $($attachmentExceptionWorksheet.summary.worksheet_rows)."
}

if (-not $attachmentExceptionWorksheetImportPreview) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Generate attachment exception worksheet import preview' 'legacy-attachment-exception-worksheet-import-preview.json' 'open' 'Run New-LegacyAttachmentExceptionWorksheetImportPreview.ps1.'
} elseif ($attachmentExceptionWorksheetImportPreview.summary.blocked_rows -gt 0) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Fix blocked attachment worksheet import rows' 'legacy-attachment-exception-worksheet-import-preview.json' 'open' "Blocked rows: $($attachmentExceptionWorksheetImportPreview.summary.blocked_rows). Fix invalid or partially filled worksheet rows."
} elseif ($attachmentExceptionWorksheetImportPreview.summary.ready_rows -eq 0) {
    Add-ChecklistItem $items 'attachments' 'warning' 'Fill attachment worksheet before template import preview' 'legacy-attachment-exception-worksheet-import-preview.json' 'open' "Ready rows: 0, pending rows: $($attachmentExceptionWorksheetImportPreview.summary.pending_rows)."
} else {
    Add-ChecklistItem $items 'attachments' 'info' 'Attachment worksheet import preview has ready rows' 'legacy-attachment-exception-worksheet-import-preview.json' 'done' "Ready rows: $($attachmentExceptionWorksheetImportPreview.summary.ready_rows)."
}

if (-not $attachmentExceptionTemplatePatchPreview) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Generate attachment exception template patch preview' 'legacy-attachment-exception-template-patch-preview.json' 'open' 'Run New-LegacyAttachmentExceptionTemplatePatchPreview.ps1.'
} elseif ($attachmentExceptionTemplatePatchPreview.summary.ready_patch_rows -eq 0) {
    Add-ChecklistItem $items 'attachments' 'warning' 'Attachment exception template patch is empty' 'legacy-attachment-exception-template-patch-preview.csv' 'open' "Ready patch rows: 0, source pending rows: $($attachmentExceptionTemplatePatchPreview.summary.source_pending_rows)."
} else {
    Add-ChecklistItem $items 'attachments' 'info' 'Attachment exception template patch preview is ready' 'legacy-attachment-exception-template-patch-preview.csv' 'done' "Ready patch rows: $($attachmentExceptionTemplatePatchPreview.summary.ready_patch_rows)."
}

if (-not $attachmentExceptionOperatorPack) {
    Add-ChecklistItem $items 'attachments' 'blocker' 'Generate attachment exception operator pack' 'legacy-attachment-exception-operator-pack.json' 'open' 'Run New-LegacyAttachmentExceptionOperatorPack.ps1.'
} elseif ($attachmentExceptionOperatorPack.overall_status -ne 'ready') {
    Add-ChecklistItem $items 'attachments' 'warning' 'Follow attachment exception operator pack next step' 'legacy-attachment-exception-operator-pack.json' 'open' "Next: $(Get-NextTitle $attachmentExceptionOperatorPack.next_step)."
} else {
    Add-ChecklistItem $items 'attachments' 'info' 'Attachment exception operator pack is ready' 'legacy-attachment-exception-operator-pack.json' 'done' 'All missing attachment exception workflow steps are ready.'
}

if ($unitUserDbMock -and $projectDbMock -and $projectFileDbMock) {
    Add-ChecklistItem $items 'mock_validation' 'info' 'Mock mapping reports are available' 'mock_reports' 'done' "mock users ready=$($unitUserDbMock.summary.ready_users), projects ready=$($projectDbMock.summary.ready_for_import), project_files ready=$($projectFileDbMock.summary.ready_for_import)."
} else {
    Add-ChecklistItem $items 'mock_validation' 'warning' 'Generate mock mapping validation reports' 'mock_reports' 'open' 'Run Invoke-LegacyMigrationReportPipeline.ps1 -WithMock.'
}

$blockers = @($items | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($items | Where-Object { $_.severity -eq 'warning' }).Count
$infos = @($items | Where-Object { $_.severity -eq 'info' }).Count
$done = @($items | Where-Object { $_.status -eq 'done' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_items = $items.Count
        blockers = $blockers
        warnings = $warnings
        info = $infos
        done = $done
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration preflight checklist written to $ReportPath"
