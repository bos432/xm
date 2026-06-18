param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-drill-operator-pack.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-FileEntry($key, $path, $purpose, $required = $true) {
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [ordered]@{
        key = $key
        path = $path
        file_name = [System.IO.Path]::GetFileName($path)
        purpose = $purpose
        required = [bool]$required
        exists = $exists
        updated_at = if ($exists) { (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') } else { $null }
    }
}

function Add-Step($steps, $order, $title, $status, $owner, $action, $acceptance, $source) {
    $steps.Add([pscustomobject][ordered]@{
        order = $order
        title = $title
        status = $status
        owner = $owner
        action = $action
        acceptance = $acceptance
        source = $source
    })
}

function Get-Status($report) {
    if ($null -eq $report) { return 'missing' }
    return $report.overall_status
}

$goLiveGatePath = Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.json'
$preflightPath = Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json'
$evidencePackPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-evidence-pack.json'
$drillReportPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-report.md'
$rollbackPlanPath = Join-Path $ScriptsRoot 'legacy-migration-rollback-plan.md'
$operatorRunbookPath = Join-Path $ScriptsRoot 'legacy-migration-operator-runbook.md'
$goLiveSignoffPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.json'
$goLiveSignoffOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack.json'
$blockerOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack.json'
$samplingOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack.json'
$workflowOrphanOperatorPath = Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack.json'
$resolutionOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack.json'

$goLiveGate = Read-JsonReport $goLiveGatePath
$preflight = Read-JsonReport $preflightPath
$evidencePack = Read-JsonReport $evidencePackPath
$goLiveSignoff = Read-JsonReport $goLiveSignoffPath
$goLiveSignoffOperator = Read-JsonReport $goLiveSignoffOperatorPath
$blockerOperator = Read-JsonReport $blockerOperatorPath
$samplingOperator = Read-JsonReport $samplingOperatorPath
$workflowOrphanOperator = Read-JsonReport $workflowOrphanOperatorPath
$resolutionOperator = Read-JsonReport $resolutionOperatorPath
$rollbackRunbookStatus = if ((Test-Path -LiteralPath $rollbackPlanPath -PathType Leaf) -and (Test-Path -LiteralPath $operatorRunbookPath -PathType Leaf)) { 'ready' } else { 'missing' }

$steps = New-Object System.Collections.Generic.List[object]
Add-Step $steps 1 'Generate full report and evidence pack' (Get-Status $evidencePack) 'technical_owner' 'Run the full report pipeline and confirm the evidence ZIP exists.' 'Evidence pack has zero missing required files and ZIP exists.' $evidencePackPath
Add-Step $steps 2 'Resolve preflight blockers' (Get-Status $preflight) 'technical_owner' 'Close every blocker and review warnings before execution rehearsal.' 'Preflight status is ready or accepted warnings are documented.' $preflightPath
Add-Step $steps 3 'Review blocker resolution workflow' (Get-Status $blockerOperator) 'ops_owner' 'Use the blocker operator pack to approve, execute, and verify blocked stages.' 'Blocked stages are verified or explicitly accepted with risk.' $blockerOperatorPath
Add-Step $steps 4 'Complete mapping resolution acceptance' (Get-Status $resolutionOperator) 'data_migration_owner' 'Use resolution operator pack to complete mappings and dry-run comparisons.' 'Resolution acceptance gate has no blockers and warnings are accepted.' $resolutionOperatorPath
Add-Step $steps 5 'Complete business sampling acceptance' (Get-Status $samplingOperator) 'business_owner' 'Use the sampling operator pack to review all selected samples.' 'Every sample is pass or accepted_with_risk.' $samplingOperatorPath
Add-Step $steps 6 'Decide orphan workflow handling' (Get-Status $workflowOrphanOperator) 'business_owner' 'Use the orphan workflow operator pack to decide archive, link, or exclude.' 'Every orphan workflow row has an approved handling decision.' $workflowOrphanOperatorPath
Add-Step $steps 7 'Review rollback and operator runbook' $rollbackRunbookStatus 'operations_owner' 'Review rollback plan, runbook, backup owners, and command boundaries.' 'Rollback plan and operator runbook are present and reviewed by operations.' 'rollback_runbook'
Add-Step $steps 8 'Collect final role signoff' (Get-Status $goLiveSignoffOperator) 'all_owners' 'Use the go-live signoff operator pack to collect role-level signoff.' 'Every role is signed or accepted_with_risk.' $goLiveSignoffOperatorPath
Add-Step $steps 9 'Review go-live gate' (Get-Status $goLiveGate) 'technical_owner' 'Confirm the go-live gate before any write window or traffic switch.' 'Go-live gate is ready and write_cutover_ready is true.' $goLiveGatePath

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'blocked' -or $_.status -eq 'missing' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'open' -or $_.status -eq 'warning' })
$readySteps = @($steps.ToArray() | Where-Object { $_.status -eq 'ready' -or $_.status -eq 'pass' })

$nextStep = $null
foreach ($step in @($steps.ToArray())) {
    if ($step.status -ne 'ready' -and $step.status -ne 'pass') {
        $nextStep = $step
        break
    }
}

$files = @(
    New-FileEntry 'go_live_gate' $goLiveGatePath 'go/no-go gate status'
    New-FileEntry 'preflight_checklist' $preflightPath 'preflight blockers and warnings'
    New-FileEntry 'evidence_pack' $evidencePackPath 'go-live evidence package manifest'
    New-FileEntry 'evidence_pack_zip' (Join-Path $ScriptsRoot 'legacy-migration-go-live-evidence-pack.zip') 'go-live evidence ZIP package'
    New-FileEntry 'drill_report' $drillReportPath 'manual go-live drill report template'
    New-FileEntry 'rollback_plan' $rollbackPlanPath 'rollback plan template'
    New-FileEntry 'operator_runbook' $operatorRunbookPath 'operator runbook'
    New-FileEntry 'go_live_signoff' $goLiveSignoffPath 'final role signoff report'
    New-FileEntry 'go_live_signoff_operator_pack' $goLiveSignoffOperatorPath 'operator pack for role signoff'
    New-FileEntry 'blocker_resolution_operator_pack' $blockerOperatorPath 'operator pack for blocked stages'
    New-FileEntry 'sampling_acceptance_operator_pack' $samplingOperatorPath 'operator pack for business sampling'
    New-FileEntry 'workflow_orphan_operator_pack' $workflowOrphanOperatorPath 'operator pack for orphan workflow handling'
    New-FileEntry 'resolution_operator_pack' $resolutionOperatorPath 'operator pack for mapping resolution'
)

$missingRequiredFiles = @($files | Where-Object { $_.required -and -not $_.exists })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This drill operator pack summarizes go-live rehearsal readiness. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_steps = $steps.Count
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
        evidence_files = if ($evidencePack) { $evidencePack.summary.evidence_files } else { 0 }
        evidence_missing_required = if ($evidencePack) { $evidencePack.summary.missing_required } else { $missingRequiredFiles.Count }
        evidence_zip_exists = if ($evidencePack) { $evidencePack.summary.zip_exists } else { Test-Path -LiteralPath (Join-Path $ScriptsRoot 'legacy-migration-go-live-evidence-pack.zip') -PathType Leaf }
        preflight_blockers = if ($preflight) { $preflight.summary.blockers } else { 0 }
        preflight_warnings = if ($preflight) { $preflight.summary.warnings } else { 0 }
        go_live_gate_status = if ($goLiveGate) { $goLiveGate.overall_status } else { 'missing' }
        write_cutover_ready = if ($goLiveGate) { [bool]$goLiveGate.write_cutover_ready } else { $false }
        role_signoff_pending = if ($goLiveSignoff) { $goLiveSignoff.summary.pending_items } else { 0 }
    }
    next_step = $nextStep
    files = @($files)
    missing_required_files = @($missingRequiredFiles | ForEach-Object { $_.key })
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live drill operator pack written to $ReportPath"
