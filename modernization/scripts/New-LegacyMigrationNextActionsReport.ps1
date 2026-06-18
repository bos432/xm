param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.md"),
    [string]$BlockerCsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.blockers.csv"),
    [string]$BlockerMarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.blockers.md"),
    [string]$OwnerFilesPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.json"),
    [string]$OwnerZipPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.zip")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Value($value, $fallback = '-') {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $fallback }
    return [string]$value
}

function Get-FirstItem($value) {
    if ($null -eq $value) { return $null }
    if ($value -is [array]) {
        if ($value.Count -eq 0) { return $null }
        return $value[0]
    }
    return $value
}

function Get-NextField($value, $field, $fallback = '-') {
    $item = Get-FirstItem $value
    if ($null -eq $item) { return $fallback }
    if ($item.PSObject.Properties.Name -contains $field) {
        return Get-Value $item.$field $fallback
    }
    return $fallback
}

function Get-Priority($severity) {
    if ($severity -eq 'blocker') { return 1 }
    if ($severity -eq 'warning') { return 2 }
    return 3
}

function Add-Action($items, $category, $severity, $status, $title, $owner, $source, $evidence, $action, $acceptance) {
    $items.Add([pscustomobject][ordered]@{
        priority = Get-Priority $severity
        category = $category
        severity = $severity
        status = $status
        title = $title
        owner = Get-Value $owner 'unassigned'
        source = $source
        evidence = Get-Value $evidence
        action = Get-Value $action
        acceptance = Get-Value $acceptance
    })
}

function Format-MarkdownText($value) {
    return (Get-Value $value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Get-Slug($value) {
    $slug = ([string](Get-Value $value 'unassigned')).Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) { return 'unassigned' }
    return $slug
}

function Write-ActionsMarkdown($path, $title, $items) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $title")
    $lines.Add('')
    $lines.Add('Generated at: ' + (Get-Date -Format o))
    $lines.Add('')
    $lines.Add('| Priority | Severity | Category | Status | Owner | Title | Action | Acceptance |')
    $lines.Add('| ---: | --- | --- | --- | --- | --- | --- | --- |')
    foreach ($item in @($items)) {
        $lines.Add("| $($item.priority) | $(Format-MarkdownText $item.severity) | $(Format-MarkdownText $item.category) | $(Format-MarkdownText $item.status) | $(Format-MarkdownText $item.owner) | $(Format-MarkdownText $item.title) | $(Format-MarkdownText $item.action) | $(Format-MarkdownText $item.acceptance) |")
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
}

$preflight = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json')
$preflightValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist-validation.json')
$goLiveGate = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.json')
$goLiveGateValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate-validation.json')
$attachmentExceptionOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-operator-pack.json')
$attachmentExceptionOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-exception-operator-pack-validation.json')
$blockerActionSheetValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-action-sheet-validation.json')
$blockerSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff.json')
$blockerSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff-validation.json')
$blockerResolutionPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-pack-validation.json')
$blockerOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack.json')
$blockerOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack-validation.json')
$resolutionGate = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-acceptance-gate.json')
$resolutionOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack.json')
$resolutionOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack-validation.json')
$samplingSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff.json')
$samplingSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff-validation.json')
$samplingOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack.json')
$samplingOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack-validation.json')
$workflowOrphanSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff.json')
$workflowOrphanSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff-validation.json')
$workflowOrphanOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack.json')
$workflowOrphanOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack-validation.json')
$goLiveSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.json')
$goLiveSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-validation.json')
$goLiveSignoffOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack.json')
$goLiveSignoffOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack-validation.json')
$goLiveDrillOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack.json')
$goLiveDrillOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack-validation.json')
$operationalDocsValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-operational-docs-validation.json')
$securityBaselineOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack.json')
$securityBaselineOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack-validation.json')
$securityBaselineSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.json')
$securityBaselineSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff-validation.json')
$securityPublicExecutableWorklistValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist-validation.json')
$securityPublicExecutableRemediationPlan = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan.json')
$securityPublicExecutableRemediationPlanValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan-validation.json')
$securityPublicExecutableRemediationWaveFilesValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files-validation.json')
$securityPublicExecutableRemediationWaveSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff.json')
$securityPublicExecutableRemediationWaveSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-validation.json')
$securityPublicExecutableRemediationWaveSignoffOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json')
$securityPublicExecutableRemediationWaveSignoffOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json')
$securityPublicExecutableRemediationWaveSignoffHandoffPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json')
$securityPublicExecutableRemediationWaveSignoffHandoffPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json')
$securityPublicExecutableRemediationWaveSignoffHandoffSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json')
$securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json')
$securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json')
$securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json')
$evidencePack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-evidence-pack.json')
$evidencePackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-evidence-pack-validation.json')
$manifest = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json')
$manifestValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest-validation.json')
$preflightBlockerOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack.json')
$preflightBlockerOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack-validation.json')
$nextActionsOwnerSignoff = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff.json')
$nextActionsOwnerSignoffValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-validation.json')
$nextActionsOwnerSignoffOperatorPack = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-operator-pack.json')
$nextActionsOwnerSignoffOperatorPackValidation = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-operator-pack-validation.json')
$workflowDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-db-dry-run.json')

$items = New-Object System.Collections.Generic.List[object]

if (-not $preflight) {
    Add-Action $items 'preflight' 'blocker' 'open' 'Generate preflight checklist' 'technical_owner' 'legacy-migration-preflight-checklist.json' 'Report is missing.' 'Run New-LegacyMigrationPreflightChecklist.ps1.' 'Preflight report exists with no blockers.'
} else {
    foreach ($item in @($preflight.items | Where-Object { $_.severity -eq 'blocker' -or $_.severity -eq 'warning' })) {
        Add-Action $items 'preflight' $item.severity $item.status $item.title 'technical_owner' $item.source $item.action $item.action 'Item is closed or signed off.'
    }
}

if (-not $preflightValidation) {
    Add-Action $items 'preflight_validation' 'blocker' 'open' 'Validate preflight checklist' 'technical_owner' 'legacy-migration-preflight-checklist-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationPreflightChecklist.ps1.' 'Preflight checklist validation exists with zero blockers and zero warnings.'
} elseif ($preflightValidation.summary.blockers -gt 0 -or $preflightValidation.summary.warnings -gt 0) {
    foreach ($issue in @($preflightValidation.issues)) {
        Add-Action $items 'preflight_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-preflight-checklist-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the preflight checklist and fix any remaining consistency issue.' 'Preflight checklist validation blockers and warnings are zero.'
    }
}

if (-not $goLiveGate) {
    Add-Action $items 'go_live_gate' 'blocker' 'open' 'Generate go-live gate' 'technical_owner' 'legacy-migration-go-live-gate.json' 'Report is missing.' 'Run New-LegacyMigrationGoLiveGate.ps1.' 'Go-live gate exists and is ready.'
} else {
    foreach ($gate in @($goLiveGate.gates | Where-Object { $_.status -ne 'pass' })) {
        Add-Action $items 'go_live_gate' $gate.severity $gate.status $gate.title 'technical_owner' $gate.source $gate.evidence $gate.action $gate.acceptance
    }
}

if (-not $goLiveGateValidation) {
    Add-Action $items 'go_live_gate_validation' 'blocker' 'open' 'Validate go-live gate' 'technical_owner' 'legacy-migration-go-live-gate-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationGoLiveGate.ps1.' 'Go-live gate validation exists with zero blockers and zero warnings.'
} elseif ($goLiveGateValidation.summary.blockers -gt 0 -or $goLiveGateValidation.summary.warnings -gt 0) {
    foreach ($issue in @($goLiveGateValidation.issues)) {
        Add-Action $items 'go_live_gate_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-go-live-gate-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the go-live gate and fix any remaining consistency issue.' 'Go-live gate validation blockers and warnings are zero.'
    }
}

if (-not $attachmentExceptionOperatorPack) {
    Add-Action $items 'attachment_exception_operator_pack' 'blocker' 'open' 'Generate attachment exception operator pack' 'data_migration_owner' 'legacy-attachment-exception-operator-pack.json' 'Report is missing.' 'Run New-LegacyAttachmentExceptionOperatorPack.ps1.' 'Operator pack exists and summarizes missing attachment decisions.'
} elseif ($attachmentExceptionOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'attachment_exception_operator_pack' 'warning' $attachmentExceptionOperatorPack.overall_status 'Use attachment exception operator pack' 'data_migration_owner' 'legacy-attachment-exception-operator-pack.json' "missing=$($attachmentExceptionOperatorPack.summary.missing_attachments), pending=$($attachmentExceptionOperatorPack.summary.pending_decisions), patch_rows=$($attachmentExceptionOperatorPack.summary.patch_rows)" (Get-NextField $attachmentExceptionOperatorPack.next_step 'action') (Get-NextField $attachmentExceptionOperatorPack.next_step 'acceptance')
}

if (-not $attachmentExceptionOperatorPackValidation) {
    Add-Action $items 'attachment_exception_operator_pack_validation' 'blocker' 'open' 'Validate attachment exception operator pack' 'data_migration_owner' 'legacy-attachment-exception-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyAttachmentExceptionOperatorPack.ps1.' 'Attachment exception operator pack validation exists with zero blockers and zero warnings.'
} elseif ($attachmentExceptionOperatorPackValidation.summary.blockers -gt 0 -or $attachmentExceptionOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($attachmentExceptionOperatorPackValidation.issues)) {
        Add-Action $items 'attachment_exception_operator_pack_validation' $issue.severity 'open' $issue.message 'data_migration_owner' 'legacy-attachment-exception-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the attachment exception operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $blockerActionSheetValidation) {
    Add-Action $items 'blocker_action_sheet_validation' 'blocker' 'open' 'Validate blocker action sheet' 'technical_owner' 'legacy-migration-blocker-action-sheet-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationBlockerActionSheet.ps1.' 'Blocker action sheet validation exists with zero blockers and zero warnings.'
} elseif ($blockerActionSheetValidation.summary.blockers -gt 0 -or $blockerActionSheetValidation.summary.warnings -gt 0) {
    foreach ($issue in @($blockerActionSheetValidation.issues)) {
        Add-Action $items 'blocker_action_sheet_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-blocker-action-sheet-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the blocker action sheet and fix any remaining consistency issue.' 'Blocker action sheet validation blockers and warnings are zero.'
    }
}

if (-not $blockerSignoff) {
    Add-Action $items 'blocker_resolution_signoff' 'blocker' 'open' 'Generate blocker resolution signoff' 'technical_owner' 'legacy-migration-blocker-resolution-signoff.json' 'Report is missing.' 'Run New-LegacyMigrationBlockerResolutionSignoff.ps1.' 'All blocked stages are verified.'
} else {
    foreach ($item in @($blockerSignoff.items | Where-Object { $_.status -ne 'verified' })) {
        $severity = if ($item.status -eq 'blocked' -or $item.status -eq 'invalid') { 'blocker' } else { 'warning' }
        $evidence = "status=$($item.status), blocked=$($item.blocked_count), owner=$($item.owner)"
        Add-Action $items 'blocker_resolution_signoff' $severity $item.status "Complete blocker resolution signoff: $($item.stage)" $item.owner 'legacy-migration-blocker-resolution-signoff.csv' $evidence 'Fill approval, execution, and verification fields after the real resolution step is complete.' 'Status is verified and validation has no blockers.'
    }
}

if (-not $blockerResolutionPackValidation) {
    Add-Action $items 'blocker_resolution_pack_validation' 'blocker' 'open' 'Validate blocker resolution pack' 'technical_owner' 'legacy-migration-blocker-resolution-pack-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationBlockerResolutionPack.ps1.' 'Blocker resolution pack validation exists with zero blockers and zero warnings.'
} elseif ($blockerResolutionPackValidation.summary.blockers -gt 0 -or $blockerResolutionPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($blockerResolutionPackValidation.issues)) {
        Add-Action $items 'blocker_resolution_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-blocker-resolution-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the blocker resolution pack and fix any remaining consistency issue.' 'Blocker resolution pack validation blockers and warnings are zero.'
    }
}

if ($blockerSignoffValidation -and (($blockerSignoffValidation.summary.blockers -gt 0) -or ($blockerSignoffValidation.summary.warnings -gt 0))) {
    foreach ($issue in @($blockerSignoffValidation.issues)) {
        Add-Action $items 'blocker_resolution_signoff_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-blocker-resolution-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced signoff CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $blockerOperatorPack) {
    Add-Action $items 'blocker_resolution_operator_pack' 'blocker' 'open' 'Generate blocker resolution operator pack' 'technical_owner' 'legacy-migration-blocker-resolution-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationBlockerResolutionOperatorPack.ps1.' 'Operator pack exists and summarizes approval, execution, and verification.'
} elseif ($blockerOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'blocker_resolution_operator_pack' 'warning' $blockerOperatorPack.overall_status 'Use blocker resolution operator pack' 'technical_owner' 'legacy-migration-blocker-resolution-operator-pack.json' "pending=$($blockerOperatorPack.summary.pending_items), approved=$($blockerOperatorPack.summary.approved_items), executed=$($blockerOperatorPack.summary.executed_items), verified=$($blockerOperatorPack.summary.verified_items)" (Get-NextField $blockerOperatorPack.next_step 'action') (Get-NextField $blockerOperatorPack.next_step 'acceptance')
}

if (-not $blockerOperatorPackValidation) {
    Add-Action $items 'blocker_resolution_operator_pack_validation' 'blocker' 'open' 'Validate blocker resolution operator pack' 'technical_owner' 'legacy-migration-blocker-resolution-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationBlockerResolutionOperatorPack.ps1.' 'Blocker resolution operator pack validation exists with zero blockers and zero warnings.'
} elseif ($blockerOperatorPackValidation.summary.blockers -gt 0 -or $blockerOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($blockerOperatorPackValidation.issues)) {
        Add-Action $items 'blocker_resolution_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-blocker-resolution-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the blocker resolution operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $resolutionGate) {
    Add-Action $items 'resolution_acceptance' 'blocker' 'open' 'Generate resolution acceptance gate' 'technical_owner' 'legacy-migration-resolution-acceptance-gate.json' 'Report is missing.' 'Run New-LegacyMigrationResolutionAcceptanceGate.ps1.' 'Resolution acceptance gate is ready.'
} else {
    foreach ($gate in @($resolutionGate.gates | Where-Object { $_.status -ne 'pass' })) {
        Add-Action $items 'resolution_acceptance' $gate.severity $gate.status $gate.title 'business_owner' $gate.source $gate.evidence $gate.action $gate.acceptance
    }
}

if (-not $resolutionOperatorPack) {
    Add-Action $items 'resolution_operator_pack' 'blocker' 'open' 'Generate resolution operator pack' 'technical_owner' 'legacy-migration-resolution-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationResolutionOperatorPack.ps1.' 'Resolution operator pack exists and summarizes mapping resolution readiness.'
} elseif ($resolutionOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'resolution_operator_pack' 'warning' $resolutionOperatorPack.overall_status 'Use resolution operator pack' 'technical_owner' 'legacy-migration-resolution-operator-pack.json' "pending_rows=$($resolutionOperatorPack.summary.pending_rows), p1=$($resolutionOperatorPack.summary.p1_items), acceptance_warnings=$($resolutionOperatorPack.summary.acceptance_warnings)" (Get-NextField $resolutionOperatorPack.next_step 'action') (Get-NextField $resolutionOperatorPack.next_step 'acceptance')
}

if (-not $resolutionOperatorPackValidation) {
    Add-Action $items 'resolution_operator_pack_validation' 'blocker' 'open' 'Validate resolution operator pack' 'technical_owner' 'legacy-migration-resolution-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationResolutionOperatorPack.ps1.' 'Resolution operator pack validation exists with zero blockers and zero warnings.'
} elseif ($resolutionOperatorPackValidation.summary.blockers -gt 0 -or $resolutionOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($resolutionOperatorPackValidation.issues)) {
        Add-Action $items 'resolution_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-resolution-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the resolution operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $goLiveSignoff) {
    Add-Action $items 'go_live_signoff' 'blocker' 'open' 'Generate final role signoff sheet' 'technical_owner' 'legacy-migration-go-live-signoff.json' 'Report is missing.' 'Run New-LegacyMigrationGoLiveSignoff.ps1.' 'Every role is signed or accepted with risk.'
} else {
    foreach ($item in @($goLiveSignoff.items | Where-Object { $_.status -ne 'signed' -and $_.status -ne 'accepted_with_risk' })) {
        $severity = if ($item.status -eq 'rejected' -or $item.status -eq 'invalid') { 'blocker' } else { 'warning' }
        $evidence = "status=$($item.status), owner=$($item.owner), signed_by=$($item.signed_by)"
        Add-Action $items 'go_live_signoff' $severity $item.status "Complete go-live role signoff: $($item.role_name)" $item.owner 'legacy-migration-go-live-signoff.csv' $evidence 'Collect owner, signed_by, signed_at, and notes when risk is accepted.' 'Role status is signed or accepted_with_risk.'
    }
}

if (-not $samplingSignoff) {
    Add-Action $items 'sampling_acceptance' 'blocker' 'open' 'Generate business sampling acceptance signoff' 'business_owner' 'legacy-migration-sampling-acceptance-signoff.json' 'Report is missing.' 'Run New-LegacyMigrationSamplingAcceptanceSignoff.ps1.' 'Every sample is pass or accepted_with_risk.'
} else {
    foreach ($item in @($samplingSignoff.items | Where-Object { $_.status -ne 'pass' -and $_.status -ne 'accepted_with_risk' })) {
        $severity = if ($item.status -eq 'fail' -or $item.status -eq 'blocked' -or $item.status -eq 'invalid') { 'blocker' } else { 'warning' }
        $evidence = "status=$($item.status), category=$($item.category), legacy_id=$($item.legacy_id), risk=$($item.risk_notes)"
        Add-Action $items 'sampling_acceptance' $severity $item.status "Complete sampling acceptance: $($item.sample_key)" 'business_owner' 'legacy-migration-sampling-acceptance-signoff.csv' $evidence 'Review the sample, fill sampled_by, sampled_at, evidence_ref, and set status.' 'Sample status is pass or accepted_with_risk.'
    }
}

if ($samplingSignoffValidation -and (($samplingSignoffValidation.summary.blockers -gt 0) -or ($samplingSignoffValidation.summary.warnings -gt 0))) {
    foreach ($issue in @($samplingSignoffValidation.issues)) {
        Add-Action $items 'sampling_acceptance_validation' $issue.severity 'open' $issue.message 'business_owner' 'legacy-migration-sampling-acceptance-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced sampling acceptance CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $samplingOperatorPack) {
    Add-Action $items 'sampling_acceptance_operator_pack' 'blocker' 'open' 'Generate business sampling acceptance operator pack' 'business_owner' 'legacy-migration-sampling-acceptance-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationSamplingAcceptanceOperatorPack.ps1.' 'Operator pack exists and groups samples by category.'
} elseif ($samplingOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'sampling_acceptance_operator_pack' 'warning' $samplingOperatorPack.overall_status 'Use business sampling acceptance operator pack' 'business_owner' 'legacy-migration-sampling-acceptance-operator-pack.json' "pending=$($samplingOperatorPack.summary.pending_items), categories=$($samplingOperatorPack.summary.category_count), blockers=$($samplingOperatorPack.summary.validation_blockers)" (Get-NextField $samplingOperatorPack.next_step 'action') (Get-NextField $samplingOperatorPack.next_step 'acceptance')
}

if (-not $samplingOperatorPackValidation) {
    Add-Action $items 'sampling_acceptance_operator_pack_validation' 'blocker' 'open' 'Validate business sampling acceptance operator pack' 'business_owner' 'legacy-migration-sampling-acceptance-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationSamplingAcceptanceOperatorPack.ps1.' 'Sampling acceptance operator pack validation exists with zero blockers and zero warnings.'
} elseif ($samplingOperatorPackValidation.summary.blockers -gt 0 -or $samplingOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($samplingOperatorPackValidation.issues)) {
        Add-Action $items 'sampling_acceptance_operator_pack_validation' $issue.severity 'open' $issue.message 'business_owner' 'legacy-migration-sampling-acceptance-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the sampling acceptance operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $workflowOrphanSignoff) {
    Add-Action $items 'workflow_orphan_resolution' 'blocker' 'open' 'Generate workflow orphan handling signoff' 'business_owner' 'legacy-workflow-orphan-resolution-signoff.json' 'Report is missing.' 'Run New-LegacyWorkflowOrphanResolutionSignoff.ps1.' 'Every orphan workflow row has an approved handling decision.'
} else {
    foreach ($item in @($workflowOrphanSignoff.items | Where-Object { $_.decision -ne 'archive' -and $_.decision -ne 'link' -and $_.decision -ne 'exclude' })) {
        $severity = if ($item.decision -eq 'blocked' -or $item.decision -eq 'invalid') { 'blocker' } else { 'warning' }
        $evidence = "decision=$($item.decision), legacy_id=$($item.legacy_id), legacy_project_id=$($item.legacy_project_id), source=$($item.source_table)"
        Add-Action $items 'workflow_orphan_resolution' $severity $item.decision "Decide workflow orphan row: $($item.legacy_id)" 'business_owner' 'legacy-workflow-orphan-resolution-signoff.csv' $evidence 'Choose archive, link, or exclude; fill approval and evidence fields for decided rows.' 'Decision is archive, link, or exclude and validation has no blockers.'
    }
}

if ($workflowOrphanSignoffValidation -and (($workflowOrphanSignoffValidation.summary.blockers -gt 0) -or ($workflowOrphanSignoffValidation.summary.warnings -gt 0))) {
    foreach ($issue in @($workflowOrphanSignoffValidation.issues)) {
        Add-Action $items 'workflow_orphan_resolution_validation' $issue.severity 'open' $issue.message 'business_owner' 'legacy-workflow-orphan-resolution-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced workflow orphan CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $workflowOrphanOperatorPack) {
    Add-Action $items 'workflow_orphan_operator_pack' 'blocker' 'open' 'Generate workflow orphan operator pack' 'business_owner' 'legacy-workflow-orphan-operator-pack.json' 'Report is missing.' 'Run New-LegacyWorkflowOrphanOperatorPack.ps1.' 'Operator pack exists and groups orphan rows by legacy project.'
} elseif ($workflowOrphanOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'workflow_orphan_operator_pack' 'warning' $workflowOrphanOperatorPack.overall_status 'Use workflow orphan operator pack' 'business_owner' 'legacy-workflow-orphan-operator-pack.json' "pending=$($workflowOrphanOperatorPack.summary.pending_items), legacy_projects=$($workflowOrphanOperatorPack.summary.legacy_project_count), blockers=$($workflowOrphanOperatorPack.summary.validation_blockers)" (Get-NextField $workflowOrphanOperatorPack.next_step 'action') (Get-NextField $workflowOrphanOperatorPack.next_step 'acceptance')
}

if (-not $workflowOrphanOperatorPackValidation) {
    Add-Action $items 'workflow_orphan_operator_pack_validation' 'blocker' 'open' 'Validate workflow orphan operator pack' 'business_owner' 'legacy-workflow-orphan-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyWorkflowOrphanOperatorPack.ps1.' 'Workflow orphan operator pack validation exists with zero blockers and zero warnings.'
} elseif ($workflowOrphanOperatorPackValidation.summary.blockers -gt 0 -or $workflowOrphanOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($workflowOrphanOperatorPackValidation.issues)) {
        Add-Action $items 'workflow_orphan_operator_pack_validation' $issue.severity 'open' $issue.message 'business_owner' 'legacy-workflow-orphan-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the workflow orphan operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $workflowDryRun) {
    Add-Action $items 'workflow_dry_run' 'blocker' 'open' 'Generate workflow row-level dry-run report' 'technical_owner' 'legacy-workflow-db-dry-run.json' 'Report is missing.' 'Run New-LegacyWorkflowDbDryRun.ps1.' 'Workflow dry-run exists.'
} elseif ($workflowDryRun.summary.project_id_mapping_required -gt 0) {
    Add-Action $items 'workflow_dry_run' 'warning' 'open' 'Resolve workflow review project mappings' 'data_migration_owner' 'legacy-workflow-db-dry-run.json' "review_project_mapping_required=$($workflowDryRun.summary.project_id_mapping_required), reviewer_mapping_required=$($workflowDryRun.summary.reviewer_id_mapping_required)" 'Complete project ID mapping before importing workflow review rows.' 'Workflow review rows no longer require project mapping.'
} elseif ($workflowDryRun.summary.orphan_project_references -gt 0) {
    Add-Action $items 'workflow_dry_run' 'warning' 'open' 'Review orphan workflow project references' 'business_owner' 'legacy-workflow-db-dry-run.json' "orphan_project_references=$($workflowDryRun.summary.orphan_project_references), reviewer_mapping_required=$($workflowDryRun.summary.reviewer_id_mapping_required)" 'Decide whether orphan workflow rows should be archived, manually linked, or excluded with approval.' 'Every orphan workflow reference has an approved handling decision.'
}

if ($goLiveSignoffValidation -and (($goLiveSignoffValidation.summary.blockers -gt 0) -or ($goLiveSignoffValidation.summary.warnings -gt 0))) {
    foreach ($issue in @($goLiveSignoffValidation.issues)) {
        Add-Action $items 'go_live_signoff_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-go-live-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced role signoff CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $goLiveSignoffOperatorPack) {
    Add-Action $items 'go_live_signoff_operator_pack' 'blocker' 'open' 'Generate final go-live signoff operator pack' 'technical_owner' 'legacy-migration-go-live-signoff-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationGoLiveSignoffOperatorPack.ps1.' 'Operator pack exists and summarizes role signoff readiness.'
} elseif ($goLiveSignoffOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'go_live_signoff_operator_pack' 'warning' $goLiveSignoffOperatorPack.overall_status 'Use final go-live signoff operator pack' 'technical_owner' 'legacy-migration-go-live-signoff-operator-pack.json' "pending=$($goLiveSignoffOperatorPack.summary.pending_items), signed=$($goLiveSignoffOperatorPack.summary.signed_items), accepted_with_risk=$($goLiveSignoffOperatorPack.summary.accepted_with_risk_items)" (Get-NextField $goLiveSignoffOperatorPack.next_step 'action') (Get-NextField $goLiveSignoffOperatorPack.next_step 'acceptance')
}

if (-not $goLiveSignoffOperatorPackValidation) {
    Add-Action $items 'go_live_signoff_operator_pack_validation' 'blocker' 'open' 'Validate final go-live signoff operator pack' 'technical_owner' 'legacy-migration-go-live-signoff-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationGoLiveSignoffOperatorPack.ps1.' 'Final go-live signoff operator pack validation exists with zero blockers and zero warnings.'
} elseif ($goLiveSignoffOperatorPackValidation.summary.blockers -gt 0 -or $goLiveSignoffOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($goLiveSignoffOperatorPackValidation.issues)) {
        Add-Action $items 'go_live_signoff_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-go-live-signoff-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the final go-live signoff operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $goLiveDrillOperatorPack) {
    Add-Action $items 'go_live_drill_operator_pack' 'blocker' 'open' 'Generate go-live drill operator pack' 'technical_owner' 'legacy-migration-go-live-drill-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationGoLiveDrillOperatorPack.ps1.' 'Operator pack exists and summarizes drill readiness.'
} elseif ($goLiveDrillOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'go_live_drill_operator_pack' $(if ($goLiveDrillOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $goLiveDrillOperatorPack.overall_status 'Use go-live drill operator pack' 'technical_owner' 'legacy-migration-go-live-drill-operator-pack.json' "blocked_steps=$($goLiveDrillOperatorPack.summary.blocked_steps), pending_steps=$($goLiveDrillOperatorPack.summary.pending_steps), next=$(Get-NextField $goLiveDrillOperatorPack.next_step 'title')" (Get-NextField $goLiveDrillOperatorPack.next_step 'action') (Get-NextField $goLiveDrillOperatorPack.next_step 'acceptance')
}

if (-not $goLiveDrillOperatorPackValidation) {
    Add-Action $items 'go_live_drill_operator_pack_validation' 'blocker' 'open' 'Validate go-live drill operator pack' 'technical_owner' 'legacy-migration-go-live-drill-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationGoLiveDrillOperatorPack.ps1.' 'Go-live drill operator pack validation exists with zero blockers and zero warnings.'
} elseif ($goLiveDrillOperatorPackValidation.summary.blockers -gt 0 -or $goLiveDrillOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($goLiveDrillOperatorPackValidation.issues)) {
        Add-Action $items 'go_live_drill_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-go-live-drill-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the go-live drill operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $operationalDocsValidation) {
    Add-Action $items 'operational_docs_validation' 'blocker' 'open' 'Validate operational docs' 'technical_owner' 'legacy-migration-operational-docs-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationOperationalDocs.ps1.' 'Operational docs validation exists with zero blockers and zero warnings.'
} elseif ($operationalDocsValidation.summary.blockers -gt 0 -or $operationalDocsValidation.summary.warnings -gt 0) {
    foreach ($issue in @($operationalDocsValidation.issues)) {
        Add-Action $items 'operational_docs_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-operational-docs-validation.json' "document=$($issue.document), field=$($issue.field), code=$($issue.code)" 'Regenerate the operational Markdown docs and fix missing sections or safety statements.' 'Operational docs validation blockers and warnings are zero.'
    }
}

if (-not $securityBaselineOperatorPack) {
    Add-Action $items 'security_baseline_operator_pack' 'blocker' 'open' 'Generate security baseline operator pack' 'security_owner' 'legacy-security-baseline-operator-pack.json' 'Report is missing.' 'Run New-LegacySecurityBaselineOperatorPack.ps1.' 'Security baseline operator pack exists and has no blocked steps.'
} elseif ($securityBaselineOperatorPack.overall_status -ne 'ready') {
    $sevs = if ($securityBaselineOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }
    Add-Action $items 'security_baseline_operator_pack' $sevs $securityBaselineOperatorPack.overall_status 'Use security baseline operator pack' 'security_owner' 'legacy-security-baseline-operator-pack.json' ("blocked_steps=" + $securityBaselineOperatorPack.summary.blocked_steps + ", pending_steps=" + $securityBaselineOperatorPack.summary.pending_steps + ", executable_public_files=" + $securityBaselineOperatorPack.summary.executable_public_files + ", attachment_dangerous_extensions=" + $securityBaselineOperatorPack.summary.attachment_dangerous_extensions) (Get-NextField $securityBaselineOperatorPack.next_step 'action') (Get-NextField $securityBaselineOperatorPack.next_step 'acceptance')
}

if (-not $securityBaselineOperatorPackValidation) {
    Add-Action $items 'security_baseline_operator_pack_validation' 'blocker' 'open' 'Validate security baseline operator pack' 'security_owner' 'legacy-security-baseline-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacySecurityBaselineOperatorPack.ps1.' 'Security baseline operator pack validation exists with zero blockers and zero warnings.'
} elseif ($securityBaselineOperatorPackValidation.summary.blockers -gt 0 -or $securityBaselineOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityBaselineOperatorPackValidation.issues)) {
        Add-Action $items 'security_baseline_operator_pack_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-baseline-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the security baseline operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $securityBaselineSignoff) {
    Add-Action $items 'security_baseline_signoff' 'blocker' 'open' 'Generate security baseline signoff sheet' 'security_owner' 'legacy-security-baseline-signoff.json' 'Report is missing.' 'Run New-LegacySecurityBaselineSignoff.ps1.' 'Security baseline signoff exists with no blockers.'
} elseif ($securityBaselineSignoff.summary.blocked_items -gt 0 -or $securityBaselineSignoff.summary.invalid_items -gt 0) {
    Add-Action $items 'security_baseline_signoff' 'blocker' $securityBaselineSignoff.overall_status 'Fix security baseline signoff blockers' 'security_owner' 'legacy-security-baseline-signoff.csv' ("blocked=" + $securityBaselineSignoff.summary.blocked_items + ", invalid=" + $securityBaselineSignoff.summary.invalid_items) 'Record mitigation or risk acceptance for blocked items.' 'Blocked and invalid signoff items are resolved.'
} elseif (($securityBaselineSignoff.summary.mitigated_items + $securityBaselineSignoff.summary.accepted_with_risk_items) -ne $securityBaselineSignoff.summary.signoff_items) {
    Add-Action $items 'security_baseline_signoff' 'warning' $securityBaselineSignoff.overall_status 'Complete security baseline signoff items' 'security_owner' 'legacy-security-baseline-signoff.csv' ("pending=" + $securityBaselineSignoff.summary.pending_items + ", mitigated=" + $securityBaselineSignoff.summary.mitigated_items + ", risk accepted=" + $securityBaselineSignoff.summary.accepted_with_risk_items) 'Fill status, owner, resolved_by, resolved_at, evidence_ref for each item.' 'Every security baseline item is mitigated or accepted_with_risk.'
}

if (-not $securityBaselineSignoffValidation) {
    Add-Action $items 'security_baseline_signoff_validation' 'blocker' 'open' 'Validate security baseline signoff fields' 'security_owner' 'legacy-security-baseline-signoff-validation.json' 'Report is missing.' 'Run Test-LegacySecurityBaselineSignoff.ps1.' 'Validation has zero blockers and zero warnings.'
} elseif ($securityBaselineSignoffValidation.summary.blockers -gt 0) {
    Add-Action $items 'security_baseline_signoff_validation' 'blocker' $securityBaselineSignoffValidation.overall_status 'Fix security baseline signoff validation blockers' 'security_owner' 'legacy-security-baseline-signoff.csv' ("blockers=" + $securityBaselineSignoffValidation.summary.blockers) 'Fix missing or invalid fields in the signoff CSV.' 'Validation blockers are zero.'
} elseif ($securityBaselineSignoffValidation.summary.warnings -gt 0) {
    Add-Action $items 'security_baseline_signoff_validation' 'warning' $securityBaselineSignoffValidation.overall_status 'Complete security baseline signoff audit fields' 'security_owner' 'legacy-security-baseline-signoff.csv' ("warnings=" + $securityBaselineSignoffValidation.summary.warnings) 'Fill owner, resolved_by, resolved_at, evidence_ref, and risk notes.' 'Validation warnings are zero.'
}

if (-not $securityPublicExecutableWorklistValidation) {
    Add-Action $items 'security_public_executable_worklist_validation' 'blocker' 'open' 'Validate public executable worklist fields' 'security_owner' 'legacy-security-public-executable-worklist-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableWorklist.ps1.' 'Public executable worklist validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableWorklistValidation.summary.blockers -gt 0 -or $securityPublicExecutableWorklistValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableWorklistValidation.issues)) {
        Add-Action $items 'security_public_executable_worklist_validation' $issue.severity 'open' "Review public executable file: $($issue.relative_path)" 'security_owner' 'legacy-security-public-executable-worklist.csv' "row=$($issue.row_number), item=$($issue.item_id), field=$($issue.field), code=$($issue.code)" 'Set status to mitigated, accepted_with_risk, or blocked; fill owner, evidence_ref, and notes when required.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationPlan) {
    Add-Action $items 'security_public_executable_remediation_plan' 'blocker' 'open' 'Generate public executable remediation waves' 'security_owner' 'legacy-security-public-executable-remediation-plan.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationPlan.ps1.' 'Remediation plan exists and groups every public executable file into a review wave.'
} elseif ($securityPublicExecutableRemediationPlan.overall_status -ne 'ready') {
    foreach ($wave in @($securityPublicExecutableRemediationPlan.waves | Where-Object { $_.status -ne 'ready' })) {
        $severity = if ($wave.blocker_files -gt 0) { 'blocker' } else { 'warning' }
        $evidence = "wave=$($wave.wave), pending=$($wave.pending_files), blockers=$($wave.blocker_files), warnings=$($wave.warning_files)"
        Add-Action $items 'security_public_executable_remediation_plan' $severity $wave.status "Complete public executable remediation wave $($wave.wave): $($wave.title)" 'security_owner' 'legacy-security-public-executable-remediation-plan.csv' $evidence 'Process this wave in the public executable worklist CSV; record mitigation, risk acceptance, owner, evidence_ref, and notes as required.' $wave.acceptance
    }
}

if (-not $securityPublicExecutableRemediationPlanValidation) {
    Add-Action $items 'security_public_executable_remediation_plan_validation' 'blocker' 'open' 'Validate public executable remediation plan coverage' 'security_owner' 'legacy-security-public-executable-remediation-plan-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationPlan.ps1.' 'Validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationPlanValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationPlanValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationPlanValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_plan_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-plan-validation.json' "item=$($issue.item_id), wave=$($issue.wave), field=$($issue.field), code=$($issue.code)" 'Regenerate the public executable worklist, remediation plan, and validation report; then fix any remaining coverage issues.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveFilesValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_files_validation' 'blocker' 'open' 'Validate public executable remediation wave package' 'security_owner' 'legacy-security-public-executable-remediation-wave-files-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveFiles.ps1.' 'Validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveFilesValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveFilesValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveFilesValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_files_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-files-validation.json' "wave=$($issue.wave), file=$($issue.file), code=$($issue.code)" 'Regenerate the public executable remediation wave files and ZIP; then fix any remaining packaging issues.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoff) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff' 'blocker' 'open' 'Generate public executable remediation wave signoff' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1.' 'Wave signoff sheet exists.'
} elseif ($securityPublicExecutableRemediationWaveSignoff.overall_status -ne 'ready') {
    foreach ($item in @($securityPublicExecutableRemediationWaveSignoff.items | Where-Object { $_.status -ne 'mitigated' -and $_.status -ne 'accepted_with_risk' })) {
        $severity = if ($item.status -eq 'blocked') { 'blocker' } else { 'warning' }
        Add-Action $items 'security_public_executable_remediation_wave_signoff' $severity $item.status "Complete public executable remediation wave signoff: wave $($item.wave)" 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff.csv' "wave=$($item.wave), pending=$($item.pending_files), blockers=$($item.blocker_files), warnings=$($item.warning_files)" 'Review the wave files, complete mitigation or risk acceptance, and fill owner, resolved_by, resolved_at, evidence_ref, and notes as required.' $item.acceptance
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoffValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_validation' 'blocker' 'open' 'Validate public executable remediation wave signoff fields' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1.' 'Validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveSignoffValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveSignoffValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveSignoffValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_signoff_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff.csv' "row=$($issue.row_number), wave=$($issue.wave), field=$($issue.field), code=$($issue.code)" 'Fix the referenced wave signoff CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoffOperatorPack) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_operator_pack' 'blocker' 'open' 'Generate public executable remediation wave signoff operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1.' 'Operator pack exists and summarizes wave signoff readiness.'
} elseif ($securityPublicExecutableRemediationWaveSignoffOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_operator_pack' $(if ($securityPublicExecutableRemediationWaveSignoffOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $securityPublicExecutableRemediationWaveSignoffOperatorPack.overall_status 'Use public executable remediation wave signoff operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json' "pending=$($securityPublicExecutableRemediationWaveSignoffOperatorPack.summary.pending_items), blocked=$($securityPublicExecutableRemediationWaveSignoffOperatorPack.summary.blocked_items), validation_blockers=$($securityPublicExecutableRemediationWaveSignoffOperatorPack.summary.validation_blockers)" (Get-NextField $securityPublicExecutableRemediationWaveSignoffOperatorPack.next_step 'action') (Get-NextField $securityPublicExecutableRemediationWaveSignoffOperatorPack.next_step 'acceptance')
}

if (-not $securityPublicExecutableRemediationWaveSignoffOperatorPackValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_operator_pack_validation' 'blocker' 'open' 'Validate public executable remediation wave signoff operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1.' 'Operator pack validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveSignoffOperatorPackValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveSignoffOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveSignoffOperatorPackValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_signoff_operator_pack_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the wave signoff operator pack and fix any remaining consistency issue.' 'Operator pack validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffPack) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_pack' 'blocker' 'open' 'Generate public executable remediation wave signoff handoff pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1.' 'Handoff pack ZIP exists and includes required wave signoff evidence.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffPack.overall_status -ne 'ready') {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_pack' $(if ($securityPublicExecutableRemediationWaveSignoffHandoffPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $securityPublicExecutableRemediationWaveSignoffHandoffPack.overall_status 'Use public executable remediation wave signoff handoff pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip' "missing_required=$($securityPublicExecutableRemediationWaveSignoffHandoffPack.summary.missing_required), pending_waves=$($securityPublicExecutableRemediationWaveSignoffHandoffPack.summary.wave_signoff_pending_items), zip_exists=$($securityPublicExecutableRemediationWaveSignoffHandoffPack.summary.zip_exists)" 'Send the handoff ZIP to the security owner and complete each wave signoff row.' 'Handoff pack is ready after every wave is mitigated or accepted_with_risk.'
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffPackValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_pack_validation' 'blocker' 'open' 'Validate public executable remediation wave signoff handoff pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1.' 'Handoff pack validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffPackValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveSignoffHandoffPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveSignoffHandoffPackValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_pack_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json' "file=$($issue.file), code=$($issue.code)" 'Regenerate the handoff pack and fix any missing files or ZIP entries.' 'Handoff pack validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffSignoff) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff' 'blocker' 'open' 'Generate public executable remediation wave handoff signoff sheet' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1.' 'Handoff signoff sheet exists.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffSignoff.overall_status -ne 'ready') {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff' $(if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoff.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $securityPublicExecutableRemediationWaveSignoffHandoffSignoff.overall_status 'Complete public executable remediation wave handoff receipt' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv' "pending=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoff.summary.pending_items), delivered=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoff.summary.delivered_items), accepted=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoff.summary.accepted_items)" 'Record recipient, sent_at, evidence_ref, accepted_by, and accepted_at after sending the handoff ZIP.' 'Handoff signoff is accepted or accepted_with_risk.'
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_validation' 'blocker' 'open' 'Validate public executable remediation wave handoff signoff fields' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1.' 'Handoff signoff validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced handoff signoff CSV row.' 'Handoff signoff validation blockers and warnings are zero.'
    }
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' 'blocker' 'open' 'Generate public executable remediation wave handoff receipt operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json' 'Report is missing.' 'Run New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1.' 'Operator pack exists and summarizes handoff receipt readiness.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' $(if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status 'Use public executable remediation wave handoff receipt operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json' "pending=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.pending_items), delivered=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.delivered_items), validation_blockers=$($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.validation_blockers)" (Get-NextField $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.next_step 'action') (Get-NextField $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.next_step 'acceptance')
}

if (-not $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) {
    Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' 'blocker' 'open' 'Validate public executable remediation wave handoff receipt operator pack' 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1.' 'Operator pack validation exists with zero blockers and zero warnings.'
} elseif ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.blockers -gt 0 -or $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.issues)) {
        Add-Action $items 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' $issue.severity 'open' $issue.message 'security_owner' 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the handoff receipt operator pack and fix any remaining consistency issue.' 'Operator pack validation blockers and warnings are zero.'
    }
}

if (-not $evidencePack) {
    Add-Action $items 'evidence_pack' 'warning' 'open' 'Generate go-live evidence pack' 'technical_owner' 'legacy-migration-go-live-evidence-pack.json' 'Evidence pack report is missing.' 'Run New-LegacyMigrationGoLiveEvidencePack.ps1.' 'Evidence pack ZIP exists and required evidence files are complete.'
} elseif ($evidencePack.summary.missing_required -gt 0 -or -not $evidencePack.summary.zip_exists) {
    Add-Action $items 'evidence_pack' 'blocker' $evidencePack.overall_status 'Fix go-live evidence pack' 'technical_owner' 'legacy-migration-go-live-evidence-pack.json' "missing_required=$($evidencePack.summary.missing_required), zip_exists=$($evidencePack.summary.zip_exists)" 'Regenerate missing reports and rebuild the evidence pack.' 'Missing required evidence is 0 and ZIP exists.'
} elseif ($evidencePack.overall_status -ne 'ready') {
    Add-Action $items 'evidence_pack' 'warning' $evidencePack.overall_status 'Review go-live evidence pack readiness' 'technical_owner' 'legacy-migration-go-live-evidence-pack.zip' "gate=$($evidencePack.summary.go_live_gate_status), preflight=$($evidencePack.summary.preflight_status)" 'Resolve go-live gate blockers before using the ZIP for final approval.' 'Evidence pack overall status is ready.'
}

if (-not $evidencePackValidation) {
    Add-Action $items 'evidence_pack_validation' 'blocker' 'open' 'Validate go-live evidence pack' 'technical_owner' 'legacy-migration-go-live-evidence-pack-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationGoLiveEvidencePack.ps1.' 'Evidence pack validation exists with zero blockers and zero warnings.'
} elseif ($evidencePackValidation.summary.blockers -gt 0 -or $evidencePackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($evidencePackValidation.issues)) {
        Add-Action $items 'evidence_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-go-live-evidence-pack-validation.json' "file=$($issue.file), code=$($issue.code)" 'Regenerate the evidence pack and fix any remaining manifest or ZIP consistency issue.' 'Evidence pack validation blockers and warnings are zero.'
    }
}

if (-not $preflightBlockerOperatorPack) {
    Add-Action $items 'preflight_blocker_operator_pack' 'blocker' 'open' 'Generate preflight blocker operator pack' 'technical_owner' 'legacy-migration-preflight-blocker-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationPreflightBlockerOperatorPack.ps1.' 'Operator pack exists and summarizes preflight blockers and warnings.'
} elseif ($preflightBlockerOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'preflight_blocker_operator_pack' $(if ($preflightBlockerOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $preflightBlockerOperatorPack.overall_status 'Use preflight blocker operator pack' 'technical_owner' 'legacy-migration-preflight-blocker-operator-pack.json' ("blockers=" + $preflightBlockerOperatorPack.summary.blockers + ", warnings=" + $preflightBlockerOperatorPack.summary.warnings + ", owners=" + $preflightBlockerOperatorPack.summary.owner_count) (Get-NextField $preflightBlockerOperatorPack.next_action 'action') (Get-NextField $preflightBlockerOperatorPack.next_action 'acceptance')
}

if (-not $preflightBlockerOperatorPackValidation) {
    Add-Action $items 'preflight_blocker_operator_pack_validation' 'blocker' 'open' 'Validate preflight blocker operator pack' 'technical_owner' 'legacy-migration-preflight-blocker-operator-pack-validation.json' 'Report is missing.' 'Run Test-LegacyMigrationPreflightBlockerOperatorPack.ps1.' 'Preflight blocker operator pack validation exists with zero blockers and zero warnings.'
} elseif ($preflightBlockerOperatorPackValidation.summary.blockers -gt 0 -or $preflightBlockerOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($preflightBlockerOperatorPackValidation.issues)) {
        Add-Action $items 'preflight_blocker_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-preflight-blocker-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the preflight blocker operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $nextActionsOwnerSignoff) {
    Add-Action $items 'next_actions_owner_signoff' 'blocker' 'open' 'Generate owner next-action handoff signoff' 'technical_owner' 'legacy-migration-next-actions.owner-signoff.json' 'Report is missing.' 'Run New-LegacyMigrationNextActionsOwnerSignoff.ps1.' 'Owner next-action signoff sheet exists.'
} else {
    foreach ($item in @($nextActionsOwnerSignoff.items | Where-Object { $_.status -ne 'completed' })) {
        $severity = if ($item.status -eq 'blocked' -or $item.status -eq 'invalid') { 'blocker' } else { 'warning' }
        $status = if ($severity -eq 'blocker') { 'blocked' } else { 'open' }
        $evidence = "status=$($item.status), action_count=$($item.action_count), blockers=$($item.blockers), recipient=$($item.recipient)"
        Add-Action $items 'next_actions_owner_signoff' $severity $status "Complete owner next-action handoff: $($item.owner)" $item.owner 'legacy-migration-next-actions.owner-signoff.csv' $evidence 'Send the owner package, record recipient, sent_at, evidence_ref, accepted_by, accepted_at, and completion fields.' 'Owner signoff status is completed and validation has no blockers.'
    }
}

if (-not $nextActionsOwnerSignoffValidation) {
    Add-Action $items 'next_actions_owner_signoff_validation' 'blocker' 'open' 'Validate owner next-action handoff signoff fields' 'technical_owner' 'legacy-migration-next-actions.owner-signoff-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationNextActionsOwnerSignoff.ps1.' 'Owner next-action signoff validation exists with zero blockers and zero warnings.'
} elseif ($nextActionsOwnerSignoffValidation.summary.blockers -gt 0 -or $nextActionsOwnerSignoffValidation.summary.warnings -gt 0) {
    foreach ($issue in @($nextActionsOwnerSignoffValidation.issues)) {
        Add-Action $items 'next_actions_owner_signoff_validation' $issue.severity 'open' $issue.message $issue.owner 'legacy-migration-next-actions.owner-signoff.csv' "row=$($issue.row_number), field=$($issue.field), code=$($issue.code)" 'Fix the referenced owner handoff signoff CSV row.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $nextActionsOwnerSignoffOperatorPack) {
    Add-Action $items 'next_actions_owner_signoff_operator_pack' 'blocker' 'open' 'Generate owner next-action handoff operator pack' 'technical_owner' 'legacy-migration-next-actions.owner-signoff-operator-pack.json' 'Report is missing.' 'Run New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1.' 'Owner handoff operator pack exists.'
} elseif ($nextActionsOwnerSignoffOperatorPack.overall_status -ne 'ready') {
    Add-Action $items 'next_actions_owner_signoff_operator_pack' $(if ($nextActionsOwnerSignoffOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) $nextActionsOwnerSignoffOperatorPack.overall_status 'Use owner next-action handoff operator pack' 'technical_owner' 'legacy-migration-next-actions.owner-signoff-operator-pack.json' "pending=$($nextActionsOwnerSignoffOperatorPack.summary.pending_items), completed=$($nextActionsOwnerSignoffOperatorPack.summary.completed_items), validation_blockers=$($nextActionsOwnerSignoffOperatorPack.summary.signoff_validation_blockers)" (Get-NextField $nextActionsOwnerSignoffOperatorPack.next_step 'action') (Get-NextField $nextActionsOwnerSignoffOperatorPack.next_step 'acceptance')
}

if (-not $nextActionsOwnerSignoffOperatorPackValidation) {
    Add-Action $items 'next_actions_owner_signoff_operator_pack_validation' 'blocker' 'open' 'Validate owner next-action handoff operator pack' 'technical_owner' 'legacy-migration-next-actions.owner-signoff-operator-pack-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1.' 'Owner handoff operator pack validation exists with zero blockers and zero warnings.'
} elseif ($nextActionsOwnerSignoffOperatorPackValidation.summary.blockers -gt 0 -or $nextActionsOwnerSignoffOperatorPackValidation.summary.warnings -gt 0) {
    foreach ($issue in @($nextActionsOwnerSignoffOperatorPackValidation.issues)) {
        Add-Action $items 'next_actions_owner_signoff_operator_pack_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-next-actions.owner-signoff-operator-pack-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the owner handoff operator pack and fix any remaining consistency issue.' 'Validation blockers and warnings are zero.'
    }
}

if (-not $manifest) {
    Add-Action $items 'artifact_manifest' 'blocker' 'open' 'Generate artifact manifest' 'technical_owner' 'legacy-migration-artifact-manifest.json' 'Report is missing.' 'Run New-LegacyMigrationArtifactManifest.ps1.' 'Manifest exists with no missing required artifacts.'
} else {
    foreach ($key in @($manifest.missing_required)) {
        $artifact = @($manifest.artifacts | Where-Object { $_.key -eq $key } | Select-Object -First 1)
        if ($artifact.Count -gt 0 -and (Test-Path -LiteralPath $artifact[0].path -PathType Leaf)) { continue }
        Add-Action $items 'artifact_manifest' 'blocker' 'open' "Generate required artifact: $key" 'technical_owner' 'legacy-migration-artifact-manifest.json' "missing=$key" 'Run the matching report script or the full pipeline.' 'Artifact exists in the manifest.'
    }
}

if (-not $manifestValidation) {
    Add-Action $items 'artifact_manifest_validation' 'blocker' 'open' 'Validate artifact manifest' 'technical_owner' 'legacy-migration-artifact-manifest-validation.json' 'Validation report is missing.' 'Run Test-LegacyMigrationArtifactManifest.ps1.' 'Artifact manifest validation exists with zero blockers and zero warnings.'
} elseif ($manifestValidation.summary.blockers -gt 0 -or $manifestValidation.summary.warnings -gt 0) {
    foreach ($issue in @($manifestValidation.issues)) {
        Add-Action $items 'artifact_manifest_validation' $issue.severity 'open' $issue.message 'technical_owner' 'legacy-migration-artifact-manifest-validation.json' "field=$($issue.field), code=$($issue.code)" 'Regenerate the artifact manifest and fix any remaining consistency issue.' 'Artifact manifest validation blockers and warnings are zero.'
    }
}

$sortedItems = @($items.ToArray() | Sort-Object priority, category, title)
$blockerItems = @($sortedItems | Where-Object { $_.severity -eq 'blocker' })
$blockers = @($sortedItems | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($sortedItems | Where-Object { $_.severity -eq 'warning' }).Count
$infos = @($sortedItems | Where-Object { $_.severity -eq 'info' }).Count

$topItems = @($sortedItems | Select-Object -First 12)
$ownerBreakdown = @($sortedItems | Group-Object owner | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name | ForEach-Object {
    [pscustomobject][ordered]@{
        owner = $_.Name
        count = $_.Count
        blockers = @($_.Group | Where-Object { $_.severity -eq 'blocker' }).Count
        warnings = @($_.Group | Where-Object { $_.severity -eq 'warning' }).Count
    }
})
$categoryBreakdown = @($sortedItems | Group-Object category | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name | ForEach-Object {
    [pscustomobject][ordered]@{
        category = $_.Name
        count = $_.Count
        blockers = @($_.Group | Where-Object { $_.severity -eq 'blocker' }).Count
        warnings = @($_.Group | Where-Object { $_.severity -eq 'warning' }).Count
    }
})
$blockerOwnerBreakdown = @($blockerItems | Group-Object owner | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name | ForEach-Object {
    [pscustomobject][ordered]@{
        owner = $_.Name
        blockers = $_.Count
        categories = @($_.Group | Select-Object -ExpandProperty category -Unique)
    }
})
$blockerCategoryBreakdown = @($blockerItems | Group-Object category | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name | ForEach-Object {
    [pscustomobject][ordered]@{
        category = $_.Name
        blockers = $_.Count
        owners = @($_.Group | Select-Object -ExpandProperty owner -Unique)
    }
})
$nextAction = $sortedItems | Select-Object -First 1
$topItems | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$ownerFiles = New-Object System.Collections.Generic.List[object]
foreach ($ownerGroup in @($sortedItems | Group-Object owner | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name)) {
    $owner = Get-Value $ownerGroup.Name 'unassigned'
    $slug = Get-Slug $owner
    $ownerCsvPath = Join-Path $ScriptsRoot "legacy-migration-next-actions.owner.$slug.csv"
    $ownerMarkdownPath = Join-Path $ScriptsRoot "legacy-migration-next-actions.owner.$slug.md"
    $ownerBlockerCsvPath = Join-Path $ScriptsRoot "legacy-migration-next-actions.owner.$slug.blockers.csv"
    $ownerBlockerMarkdownPath = Join-Path $ScriptsRoot "legacy-migration-next-actions.owner.$slug.blockers.md"
    $ownerItems = @($ownerGroup.Group | Sort-Object priority, category, title)
    $ownerBlockerItems = @($ownerItems | Where-Object { $_.severity -eq 'blocker' })
    $ownerItems | Export-Csv -LiteralPath $ownerCsvPath -Encoding UTF8 -NoTypeInformation
    Write-ActionsMarkdown $ownerMarkdownPath "Legacy Migration Next Actions - $owner" $ownerItems
    if ($ownerBlockerItems.Count -gt 0) {
        $ownerBlockerItems | Export-Csv -LiteralPath $ownerBlockerCsvPath -Encoding UTF8 -NoTypeInformation
        Write-ActionsMarkdown $ownerBlockerMarkdownPath "Legacy Migration Blocker Actions - $owner" $ownerBlockerItems
    }
    $ownerFiles.Add([pscustomobject][ordered]@{
        owner = $owner
        slug = $slug
        count = $ownerItems.Count
        blockers = $ownerBlockerItems.Count
        warnings = @($ownerItems | Where-Object { $_.severity -eq 'warning' }).Count
        csv = $ownerCsvPath
        markdown = $ownerMarkdownPath
        blocker_csv = if ($ownerBlockerItems.Count -gt 0) { $ownerBlockerCsvPath } else { $null }
        blocker_markdown = if ($ownerBlockerItems.Count -gt 0) { $ownerBlockerMarkdownPath } else { $null }
    })
}

$ownerFilesReport = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'Owner-specific next action files are generated for handoff. They do not copy files, import records, switch traffic, update templates, or write database records.'
    owner_count = $ownerFiles.Count
    zip = $OwnerZipPath
    files = @($ownerFiles.ToArray())
}
$ownerFilesReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OwnerFilesPath -Encoding UTF8

if (Test-Path -LiteralPath $OwnerZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $OwnerZipPath -Force
}

$ownerZipInputs = New-Object System.Collections.Generic.List[string]
$ownerZipInputs.Add($OwnerFilesPath)
foreach ($ownerFile in @($ownerFiles.ToArray())) {
    if (Test-Path -LiteralPath $ownerFile.csv -PathType Leaf) { $ownerZipInputs.Add($ownerFile.csv) }
    if (Test-Path -LiteralPath $ownerFile.markdown -PathType Leaf) { $ownerZipInputs.Add($ownerFile.markdown) }
    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.blocker_csv) -and (Test-Path -LiteralPath $ownerFile.blocker_csv -PathType Leaf)) { $ownerZipInputs.Add($ownerFile.blocker_csv) }
    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.blocker_markdown) -and (Test-Path -LiteralPath $ownerFile.blocker_markdown -PathType Leaf)) { $ownerZipInputs.Add($ownerFile.blocker_markdown) }
}
if ($ownerZipInputs.Count -gt 0) {
    Compress-Archive -LiteralPath @($ownerZipInputs.ToArray()) -DestinationPath $OwnerZipPath -Force
}

$ownerZipExists = Test-Path -LiteralPath $OwnerZipPath -PathType Leaf

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Legacy Migration Next Actions')
$lines.Add('')
$lines.Add('Generated at: ' + (Get-Date -Format o))
$lines.Add('')
$lines.Add('This report is preview-only. It summarizes open migration actions and does not copy legacy attachments, import records, switch traffic, update templates, or write database records.')
$lines.Add('')
$lines.Add('## Summary')
$lines.Add('')
$lines.Add('- Overall status: ' + $(if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }))
$lines.Add('- Blockers: ' + $blockers)
$lines.Add('- Warnings: ' + $warnings)
$lines.Add('- Top actions exported: ' + $topItems.Count)
$lines.Add('')
$lines.Add('## Owner Breakdown')
$lines.Add('')
$lines.Add('| Owner | Count | Blockers | Warnings |')
$lines.Add('| --- | ---: | ---: | ---: |')
foreach ($item in @($ownerBreakdown | Select-Object -First 10)) {
    $lines.Add("| $(Format-MarkdownText $item.owner) | $($item.count) | $($item.blockers) | $($item.warnings) |")
}
$lines.Add('')
$lines.Add('## Category Breakdown')
$lines.Add('')
$lines.Add('| Category | Count | Blockers | Warnings |')
$lines.Add('| --- | ---: | ---: | ---: |')
foreach ($item in @($categoryBreakdown | Select-Object -First 10)) {
    $lines.Add("| $(Format-MarkdownText $item.category) | $($item.count) | $($item.blockers) | $($item.warnings) |")
}
$lines.Add('')
$lines.Add('## Top Actions')
$lines.Add('')
$lines.Add('| Priority | Severity | Category | Status | Owner | Title | Action |')
$lines.Add('| ---: | --- | --- | --- | --- | --- | --- |')
foreach ($item in $topItems) {
    $lines.Add("| $($item.priority) | $(Format-MarkdownText $item.severity) | $(Format-MarkdownText $item.category) | $(Format-MarkdownText $item.status) | $(Format-MarkdownText $item.owner) | $(Format-MarkdownText $item.title) | $(Format-MarkdownText $item.action) |")
}
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

@($blockerItems) | Export-Csv -LiteralPath $BlockerCsvPath -Encoding UTF8 -NoTypeInformation

$blockerLines = New-Object System.Collections.Generic.List[string]
$blockerLines.Add('# Legacy Migration Blocker Actions')
$blockerLines.Add('')
$blockerLines.Add('Generated at: ' + (Get-Date -Format o))
$blockerLines.Add('')
$blockerLines.Add('This report is preview-only. It lists only blocker-level migration actions and does not copy files, import records, switch traffic, update templates, or write database records.')
$blockerLines.Add('')
$blockerLines.Add('## Summary')
$blockerLines.Add('')
$blockerLines.Add('- Blockers: ' + $blockerItems.Count)
$blockerLines.Add('- Owners: ' + $blockerOwnerBreakdown.Count)
$blockerLines.Add('- Categories: ' + $blockerCategoryBreakdown.Count)
$blockerLines.Add('')
$blockerLines.Add('## Owner Breakdown')
$blockerLines.Add('')
$blockerLines.Add('| Owner | Blockers | Categories |')
$blockerLines.Add('| --- | ---: | --- |')
foreach ($item in @($blockerOwnerBreakdown)) {
    $blockerLines.Add("| $(Format-MarkdownText $item.owner) | $($item.blockers) | $(Format-MarkdownText (($item.categories -join ', '))) |")
}
$blockerLines.Add('')
$blockerLines.Add('## Blockers')
$blockerLines.Add('')
$blockerLines.Add('| Priority | Owner | Category | Status | Title | Action | Acceptance |')
$blockerLines.Add('| ---: | --- | --- | --- | --- | --- | --- |')
foreach ($item in @($blockerItems)) {
    $blockerLines.Add("| $($item.priority) | $(Format-MarkdownText $item.owner) | $(Format-MarkdownText $item.category) | $(Format-MarkdownText $item.status) | $(Format-MarkdownText $item.title) | $(Format-MarkdownText $item.action) | $(Format-MarkdownText $item.acceptance) |")
}
$blockerLines | Set-Content -LiteralPath $BlockerMarkdownPath -Encoding UTF8

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report summarizes open migration actions. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_actions = $sortedItems.Count
        blockers = $blockers
        warnings = $warnings
        info = $infos
        top_actions = $topItems.Count
        go_live_gate_status = if ($goLiveGate) { $goLiveGate.overall_status } else { 'missing' }
        go_live_gate_validation_status = if ($goLiveGateValidation) { $goLiveGateValidation.overall_status } else { 'missing' }
        go_live_gate_validation_blockers = if ($goLiveGateValidation) { $goLiveGateValidation.summary.blockers } else { 0 }
        preflight_status = if ($preflight) { $preflight.overall_status } else { 'missing' }
        preflight_validation_status = if ($preflightValidation) { $preflightValidation.overall_status } else { 'missing' }
        preflight_validation_blockers = if ($preflightValidation) { $preflightValidation.summary.blockers } else { 0 }
        attachment_exception_operator_pack_status = if ($attachmentExceptionOperatorPack) { $attachmentExceptionOperatorPack.overall_status } else { 'missing' }
        attachment_exception_operator_pack_validation_status = if ($attachmentExceptionOperatorPackValidation) { $attachmentExceptionOperatorPackValidation.overall_status } else { 'missing' }
        attachment_exception_operator_pack_validation_blockers = if ($attachmentExceptionOperatorPackValidation) { $attachmentExceptionOperatorPackValidation.summary.blockers } else { 0 }
        blocker_action_sheet_validation_status = if ($blockerActionSheetValidation) { $blockerActionSheetValidation.overall_status } else { 'missing' }
        blocker_action_sheet_validation_blockers = if ($blockerActionSheetValidation) { $blockerActionSheetValidation.summary.blockers } else { 0 }
        blocker_resolution_operator_pack_status = if ($blockerOperatorPack) { $blockerOperatorPack.overall_status } else { 'missing' }
        blocker_resolution_pack_validation_status = if ($blockerResolutionPackValidation) { $blockerResolutionPackValidation.overall_status } else { 'missing' }
        blocker_resolution_pack_validation_blockers = if ($blockerResolutionPackValidation) { $blockerResolutionPackValidation.summary.blockers } else { 0 }
        blocker_resolution_operator_pack_validation_status = if ($blockerOperatorPackValidation) { $blockerOperatorPackValidation.overall_status } else { 'missing' }
        blocker_resolution_operator_pack_validation_blockers = if ($blockerOperatorPackValidation) { $blockerOperatorPackValidation.summary.blockers } else { 0 }
        resolution_operator_pack_status = if ($resolutionOperatorPack) { $resolutionOperatorPack.overall_status } else { 'missing' }
        resolution_operator_pack_validation_status = if ($resolutionOperatorPackValidation) { $resolutionOperatorPackValidation.overall_status } else { 'missing' }
        resolution_operator_pack_validation_blockers = if ($resolutionOperatorPackValidation) { $resolutionOperatorPackValidation.summary.blockers } else { 0 }
        go_live_signoff_operator_pack_status = if ($goLiveSignoffOperatorPack) { $goLiveSignoffOperatorPack.overall_status } else { 'missing' }
        go_live_signoff_operator_pack_validation_status = if ($goLiveSignoffOperatorPackValidation) { $goLiveSignoffOperatorPackValidation.overall_status } else { 'missing' }
        go_live_signoff_operator_pack_validation_blockers = if ($goLiveSignoffOperatorPackValidation) { $goLiveSignoffOperatorPackValidation.summary.blockers } else { 0 }
        sampling_acceptance_operator_pack_status = if ($samplingOperatorPack) { $samplingOperatorPack.overall_status } else { 'missing' }
        sampling_acceptance_operator_pack_validation_status = if ($samplingOperatorPackValidation) { $samplingOperatorPackValidation.overall_status } else { 'missing' }
        sampling_acceptance_operator_pack_validation_blockers = if ($samplingOperatorPackValidation) { $samplingOperatorPackValidation.summary.blockers } else { 0 }
        workflow_orphan_operator_pack_status = if ($workflowOrphanOperatorPack) { $workflowOrphanOperatorPack.overall_status } else { 'missing' }
        workflow_orphan_operator_pack_validation_status = if ($workflowOrphanOperatorPackValidation) { $workflowOrphanOperatorPackValidation.overall_status } else { 'missing' }
        workflow_orphan_operator_pack_validation_blockers = if ($workflowOrphanOperatorPackValidation) { $workflowOrphanOperatorPackValidation.summary.blockers } else { 0 }
        evidence_pack_status = if ($evidencePack) { $evidencePack.overall_status } else { 'missing' }
        evidence_pack_validation_status = if ($evidencePackValidation) { $evidencePackValidation.overall_status } else { 'missing' }
        evidence_pack_validation_blockers = if ($evidencePackValidation) { $evidencePackValidation.summary.blockers } else { 0 }
        go_live_drill_operator_pack_status = if ($goLiveDrillOperatorPack) { $goLiveDrillOperatorPack.overall_status } else { 'missing' }
        go_live_drill_operator_pack_validation_status = if ($goLiveDrillOperatorPackValidation) { $goLiveDrillOperatorPackValidation.overall_status } else { 'missing' }
        go_live_drill_operator_pack_validation_blockers = if ($goLiveDrillOperatorPackValidation) { $goLiveDrillOperatorPackValidation.summary.blockers } else { 0 }
        operational_docs_validation_status = if ($operationalDocsValidation) { $operationalDocsValidation.overall_status } else { 'missing' }
        operational_docs_validation_blockers = if ($operationalDocsValidation) { $operationalDocsValidation.summary.blockers } else { 0 }
        security_baseline_status = if ($securityBaselineOperatorPack) { $securityBaselineOperatorPack.overall_status } else { 'missing' }
        security_baseline_validation_status = if ($securityBaselineOperatorPackValidation) { $securityBaselineOperatorPackValidation.overall_status } else { 'missing' }
        security_baseline_validation_blockers = if ($securityBaselineOperatorPackValidation) { $securityBaselineOperatorPackValidation.summary.blockers } else { 0 }
        security_signoff_status = if ($securityBaselineSignoff) { $securityBaselineSignoff.overall_status } else { 'missing' }
        security_public_executable_worklist_validation_status = if ($securityPublicExecutableWorklistValidation) { $securityPublicExecutableWorklistValidation.overall_status } else { 'missing' }
        security_public_executable_worklist_validation_warnings = if ($securityPublicExecutableWorklistValidation) { $securityPublicExecutableWorklistValidation.summary.warnings } else { 0 }
        security_public_executable_remediation_plan_status = if ($securityPublicExecutableRemediationPlan) { $securityPublicExecutableRemediationPlan.overall_status } else { 'missing' }
        security_public_executable_remediation_pending_waves = if ($securityPublicExecutableRemediationPlan) { $securityPublicExecutableRemediationPlan.summary.pending_waves } else { 0 }
        security_public_executable_remediation_next_wave = if ($securityPublicExecutableRemediationPlan) { $securityPublicExecutableRemediationPlan.summary.next_wave } else { $null }
        security_public_executable_remediation_plan_validation_status = if ($securityPublicExecutableRemediationPlanValidation) { $securityPublicExecutableRemediationPlanValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_plan_validation_blockers = if ($securityPublicExecutableRemediationPlanValidation) { $securityPublicExecutableRemediationPlanValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_files_validation_status = if ($securityPublicExecutableRemediationWaveFilesValidation) { $securityPublicExecutableRemediationWaveFilesValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_files_validation_blockers = if ($securityPublicExecutableRemediationWaveFilesValidation) { $securityPublicExecutableRemediationWaveFilesValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_signoff_status = if ($securityPublicExecutableRemediationWaveSignoff) { $securityPublicExecutableRemediationWaveSignoff.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_pending_items = if ($securityPublicExecutableRemediationWaveSignoff) { $securityPublicExecutableRemediationWaveSignoff.summary.pending_items } else { 0 }
        security_public_executable_remediation_wave_signoff_validation_status = if ($securityPublicExecutableRemediationWaveSignoffValidation) { $securityPublicExecutableRemediationWaveSignoffValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_validation_blockers = if ($securityPublicExecutableRemediationWaveSignoffValidation) { $securityPublicExecutableRemediationWaveSignoffValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_signoff_operator_pack_status = if ($securityPublicExecutableRemediationWaveSignoffOperatorPack) { $securityPublicExecutableRemediationWaveSignoffOperatorPack.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_operator_pack_blocked_steps = if ($securityPublicExecutableRemediationWaveSignoffOperatorPack) { $securityPublicExecutableRemediationWaveSignoffOperatorPack.summary.blocked_steps } else { 0 }
        security_public_executable_remediation_wave_signoff_operator_pack_pending_steps = if ($securityPublicExecutableRemediationWaveSignoffOperatorPack) { $securityPublicExecutableRemediationWaveSignoffOperatorPack.summary.pending_steps } else { 0 }
        security_public_executable_remediation_wave_signoff_operator_pack_validation_status = if ($securityPublicExecutableRemediationWaveSignoffOperatorPackValidation) { $securityPublicExecutableRemediationWaveSignoffOperatorPackValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_operator_pack_validation_blockers = if ($securityPublicExecutableRemediationWaveSignoffOperatorPackValidation) { $securityPublicExecutableRemediationWaveSignoffOperatorPackValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_pack_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffPack) { $securityPublicExecutableRemediationWaveSignoffHandoffPack.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_pack_missing_required = if ($securityPublicExecutableRemediationWaveSignoffHandoffPack) { $securityPublicExecutableRemediationWaveSignoffHandoffPack.summary.missing_required } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_pack_validation_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffPackValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffPackValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_pack_validation_blockers = if ($securityPublicExecutableRemediationWaveSignoffHandoffPackValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffPackValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_signoff_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoff) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoff.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_signoff_pending_items = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoff) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoff.summary.pending_items } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_signoff_validation_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_signoff_validation_blockers = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.blockers } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_pending_steps = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.pending_steps } else { 0 }
        security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation_status = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.overall_status } else { 'missing' }
        security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation_blockers = if ($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.blockers } else { 0 }
        preflight_blocker_operator_pack_status = if ($preflightBlockerOperatorPack) { $preflightBlockerOperatorPack.overall_status } else { 'missing' }
        preflight_blocker_operator_pack_validation_status = if ($preflightBlockerOperatorPackValidation) { $preflightBlockerOperatorPackValidation.overall_status } else { 'missing' }
        preflight_blocker_operator_pack_validation_blockers = if ($preflightBlockerOperatorPackValidation) { $preflightBlockerOperatorPackValidation.summary.blockers } else { 0 }
        next_actions_owner_signoff_status = if ($nextActionsOwnerSignoff) { $nextActionsOwnerSignoff.overall_status } else { 'missing' }
        next_actions_owner_signoff_pending_items = if ($nextActionsOwnerSignoff) { $nextActionsOwnerSignoff.summary.pending_items } else { 0 }
        next_actions_owner_signoff_blocked_items = if ($nextActionsOwnerSignoff) { $nextActionsOwnerSignoff.summary.blocked_items } else { 0 }
        next_actions_owner_signoff_validation_status = if ($nextActionsOwnerSignoffValidation) { $nextActionsOwnerSignoffValidation.overall_status } else { 'missing' }
        next_actions_owner_signoff_validation_blockers = if ($nextActionsOwnerSignoffValidation) { $nextActionsOwnerSignoffValidation.summary.blockers } else { 0 }
        next_actions_owner_signoff_operator_pack_status = if ($nextActionsOwnerSignoffOperatorPack) { $nextActionsOwnerSignoffOperatorPack.overall_status } else { 'missing' }
        next_actions_owner_signoff_operator_pack_pending_steps = if ($nextActionsOwnerSignoffOperatorPack) { $nextActionsOwnerSignoffOperatorPack.summary.pending_steps } else { 0 }
        next_actions_owner_signoff_operator_pack_validation_status = if ($nextActionsOwnerSignoffOperatorPackValidation) { $nextActionsOwnerSignoffOperatorPackValidation.overall_status } else { 'missing' }
        next_actions_owner_signoff_operator_pack_validation_blockers = if ($nextActionsOwnerSignoffOperatorPackValidation) { $nextActionsOwnerSignoffOperatorPackValidation.summary.blockers } else { 0 }
        artifact_manifest_validation_status = if ($manifestValidation) { $manifestValidation.overall_status } else { 'missing' }
        artifact_manifest_validation_blockers = if ($manifestValidation) { $manifestValidation.summary.blockers } else { 0 }
    }
    next_action = $nextAction
    owner_breakdown = @($ownerBreakdown)
    category_breakdown = @($categoryBreakdown)
    blocker_owner_breakdown = @($blockerOwnerBreakdown)
    blocker_category_breakdown = @($blockerCategoryBreakdown)
    blocker_actions = @($blockerItems)
    top_actions = @($topItems)
    actions = @($sortedItems)
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
        blocker_csv = $BlockerCsvPath
        blocker_markdown = $BlockerMarkdownPath
        owner_manifest = $OwnerFilesPath
        owner_zip = $OwnerZipPath
        owner_zip_exists = $ownerZipExists
        owner_zip_size_bytes = if ($ownerZipExists) { (Get-Item -LiteralPath $OwnerZipPath).Length } else { $null }
        owner_files = @($ownerFiles.ToArray())
    }
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions report written to $ReportPath"
Write-Host "Legacy migration next actions CSV written to $CsvPath"
Write-Host "Legacy migration next actions markdown written to $MarkdownPath"
Write-Host "Legacy migration blocker actions CSV written to $BlockerCsvPath"
Write-Host "Legacy migration blocker actions markdown written to $BlockerMarkdownPath"
Write-Host "Legacy migration next actions owner files written to $OwnerFilesPath"
Write-Host "Legacy migration next actions owner ZIP written to $OwnerZipPath"

