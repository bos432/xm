param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$Root = (Resolve-Path "$PSScriptRoot\..\..").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-baseline-operator-pack.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-TextFile($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Add-Step($steps, $order, $category, $title, $status, $severity, $action, $acceptance, $source) {
    $steps.Add([pscustomobject][ordered]@{
        order = $order
        category = $category
        title = $title
        status = $status
        severity = $severity
        action = $action
        acceptance = $acceptance
        source = $source
    })
}

function Get-RiskSections($text) {
    $sections = [ordered]@{
        executable_public_files = New-Object System.Collections.Generic.List[string]
        dangerous_php_patterns = New-Object System.Collections.Generic.List[string]
        infected_or_backup_leftovers = New-Object System.Collections.Generic.List[string]
    }
    if (-not $text) { return $sections }

    $current = $null
    foreach ($line in ($text -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '[Executable files in public/upload roots]') { $current = 'executable_public_files'; continue }
        if ($trimmed -eq '[Dangerous patterns in PHP files]') { $current = 'dangerous_php_patterns'; continue }
        if ($trimmed -eq '[Infected or backup leftovers]') { $current = 'infected_or_backup_leftovers'; continue }
        if ($trimmed.StartsWith('[')) { $current = $null; continue }
        if ($current -and -not [string]::IsNullOrWhiteSpace($trimmed) -and -not $trimmed.StartsWith('Legacy risk scan') -and -not $trimmed.StartsWith('SiteRoot:') -and -not $trimmed.StartsWith('GeneratedAt:')) {
            $sections[$current].Add($trimmed)
        }
    }

    return $sections
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
    }
}

$riskReportPath = Join-Path $ScriptsRoot 'legacy-risk-report.txt'
$attachmentQualityPath = Join-Path $ScriptsRoot 'legacy-attachment-quality.json'
$preflightPath = Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json'
$goLiveGatePath = Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.json'
$securitySignoffPath = Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.json'
$securitySignoffValidationPath = Join-Path $ScriptsRoot 'legacy-security-baseline-signoff-validation.json'
$publicExecutableWorklistPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist.json'
$publicExecutableWorklistValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist-validation.json'
$publicExecutableRemediationPlanPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan.json'
$publicExecutableRemediationPlanValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan-validation.json'
$publicExecutableRemediationWaveFilesPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files.json'
$publicExecutableRemediationWaveFilesValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files-validation.json'
$publicExecutableRemediationWaveSignoffPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff.json'
$publicExecutableRemediationWaveSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-validation.json'
$publicExecutableRemediationWaveSignoffOperatorPackPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json'
$publicExecutableRemediationWaveSignoffOperatorPackValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json'
$publicExecutableRemediationWaveSignoffHandoffPackPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json'
$publicExecutableRemediationWaveSignoffHandoffPackValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json'
$publicExecutableRemediationWaveSignoffHandoffSignoffPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json'
$publicExecutableRemediationWaveSignoffHandoffSignoffValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json'
$publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json'
$publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath = Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json'
$securityBaselinePath = Join-Path $Root 'modernization\docs\security-baseline.md'
$acceptanceChecklistPath = Join-Path $Root 'modernization\docs\acceptance-checklist.md'
$nginxParallelConfigPath = Join-Path $Root 'modernization\docs\nginx-parallel-rollout.example.conf'

$riskText = Read-TextFile $riskReportPath
$sections = Get-RiskSections $riskText
$attachmentQuality = Read-JsonReport $attachmentQualityPath
$preflight = Read-JsonReport $preflightPath
$goLiveGate = Read-JsonReport $goLiveGatePath
$securitySignoff = Read-JsonReport $securitySignoffPath
$securitySignoffValidation = Read-JsonReport $securitySignoffValidationPath
$publicExecutableWorklist = Read-JsonReport $publicExecutableWorklistPath
$publicExecutableWorklistValidation = Read-JsonReport $publicExecutableWorklistValidationPath
$publicExecutableRemediationPlan = Read-JsonReport $publicExecutableRemediationPlanPath
$publicExecutableRemediationPlanValidation = Read-JsonReport $publicExecutableRemediationPlanValidationPath
$publicExecutableRemediationWaveFiles = Read-JsonReport $publicExecutableRemediationWaveFilesPath
$publicExecutableRemediationWaveFilesValidation = Read-JsonReport $publicExecutableRemediationWaveFilesValidationPath
$publicExecutableRemediationWaveSignoff = Read-JsonReport $publicExecutableRemediationWaveSignoffPath
$publicExecutableRemediationWaveSignoffValidation = Read-JsonReport $publicExecutableRemediationWaveSignoffValidationPath
$publicExecutableRemediationWaveSignoffOperatorPack = Read-JsonReport $publicExecutableRemediationWaveSignoffOperatorPackPath
$publicExecutableRemediationWaveSignoffOperatorPackValidation = Read-JsonReport $publicExecutableRemediationWaveSignoffOperatorPackValidationPath
$publicExecutableRemediationWaveSignoffHandoffPack = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffPackPath
$publicExecutableRemediationWaveSignoffHandoffPackValidation = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffPackValidationPath
$publicExecutableRemediationWaveSignoffHandoffSignoff = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffSignoffPath
$publicExecutableRemediationWaveSignoffHandoffSignoffValidation = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffSignoffValidationPath
$publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath
$publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation = Read-JsonReport $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath

$executablePublicFiles = $sections.executable_public_files.Count
$dangerousPatterns = $sections.dangerous_php_patterns.Count
$infectedLeftovers = $sections.infected_or_backup_leftovers.Count
$attachmentDangerous = if ($attachmentQuality) { $attachmentQuality.summary.dangerous_extensions } else { 0 }
$attachmentMissing = if ($attachmentQuality) { $attachmentQuality.summary.missing_files } else { 0 }

$steps = New-Object System.Collections.Generic.List[object]
Add-Step $steps 1 'legacy_public_surface' 'Review executable files in public and upload roots' $(if ($executablePublicFiles -gt 0) { 'blocked' } else { 'ready' }) 'blocker' 'Confirm public exposure is blocked or quarantine plan is approved before go-live.' 'Public/upload roots cannot execute PHP, ASP, JSP, or editor demo handlers.' $riskReportPath
Add-Step $steps 2 'legacy_infection_leftovers' 'Review infected and backup leftovers' $(if ($infectedLeftovers -gt 0) { 'blocked' } else { 'ready' }) 'blocker' 'Confirm infected, backup, and old upload remnants are not web-accessible.' 'Legacy leftovers are quarantined, access-restricted, or documented for read-only archive.' $riskReportPath
Add-Step $steps 3 'legacy_php_patterns' 'Review dangerous PHP patterns' $(if ($dangerousPatterns -gt 0) { 'not_ready' } else { 'ready' }) 'warning' 'Review dangerous patterns and distinguish library comments from active upload/write code.' 'Active risky code is isolated from public execution or accepted with documented risk.' $riskReportPath
Add-Step $steps 4 'attachment_quality' 'Review attachment quality security flags' $(if ($attachmentDangerous -gt 0) { 'blocked' } elseif ($attachmentMissing -gt 0) { 'not_ready' } else { 'ready' }) $(if ($attachmentDangerous -gt 0) { 'blocker' } else { 'warning' }) 'Review dangerous attachment extensions and missing files before copy execution.' 'No dangerous attachment extensions are copied; missing attachments have recovery or exception decisions.' $attachmentQualityPath
Add-Step $steps 5 'new_upload_download' 'Confirm new upload and download controls' 'not_ready' 'warning' 'Use acceptance checklist to verify upload deny-list, private storage, auth download, size, MIME, and extension controls.' 'Security acceptance checklist is sampled and signed by security_owner.' $acceptanceChecklistPath
Add-Step $steps 6 'legacy_read_only_boundary' 'Confirm legacy read-only boundary' 'not_ready' 'warning' 'Use nginx parallel rollout example and operations runbook to restrict old write/upload/admin entry points.' 'Old system write paths are disabled or IP/account restricted during parallel operation.' $nginxParallelConfigPath
Add-Step $steps 7 'security_baseline_signoff' 'Collect security baseline signoff' $(if ($securitySignoff -and $securitySignoff.overall_status -eq 'ready') { 'ready' } elseif ($securitySignoff -and $securitySignoff.overall_status -eq 'blocked') { 'blocked' } else { 'not_ready' }) $(if ($securitySignoff -and $securitySignoff.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use legacy-security-baseline-signoff.csv to record mitigation or risk acceptance for every security baseline step.' 'Every security item is mitigated or accepted_with_risk and validation has no blockers.' $securitySignoffPath
Add-Step $steps 8 'security_baseline_signoff_validation' 'Validate security baseline signoff fields' $(if ($securitySignoffValidation) { $securitySignoffValidation.overall_status } else { 'missing' }) $(if ($securitySignoffValidation -and $securitySignoffValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Fill owner, resolved_by, resolved_at, evidence_ref, and risk notes for reviewed rows.' 'Validation has zero blockers and zero warnings.' $securitySignoffValidationPath
Add-Step $steps 9 'public_executable_worklist_validation' 'Validate public executable worklist fields' $(if ($publicExecutableWorklistValidation) { $publicExecutableWorklistValidation.overall_status } else { 'missing' }) $(if ($publicExecutableWorklistValidation -and $publicExecutableWorklistValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Use legacy-security-public-executable-worklist.csv to record file-level mitigation evidence or risk notes.' 'Every reviewed public executable row has a valid status, owner, evidence_ref, and required notes.' $publicExecutableWorklistValidationPath
Add-Step $steps 10 'public_executable_remediation_plan' 'Use public executable remediation waves' $(if ($publicExecutableRemediationPlan) { $publicExecutableRemediationPlan.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationPlan -and $publicExecutableRemediationPlan.summary.pending_files -gt 0) { 'warning' } else { 'warning' }) 'Use the wave-based remediation plan to process uploaded payloads, editor handlers, static scripts, and legacy admin scripts in order.' 'Every public executable remediation wave is ready or accepted with documented residual risk.' $publicExecutableRemediationPlanPath
Add-Step $steps 11 'public_executable_remediation_plan_validation' 'Validate public executable remediation plan coverage' $(if ($publicExecutableRemediationPlanValidation) { $publicExecutableRemediationPlanValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationPlanValidation -and $publicExecutableRemediationPlanValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Confirm every public executable worklist row is covered by exactly one remediation wave and CSV row.' 'Validation has zero blockers and zero warnings.' $publicExecutableRemediationPlanValidationPath
Add-Step $steps 12 'public_executable_remediation_wave_files' 'Distribute public executable remediation wave files' $(if ($publicExecutableRemediationWaveFiles) { $publicExecutableRemediationWaveFiles.overall_status } else { 'missing' }) 'warning' 'Use the wave-specific CSV/Markdown files and ZIP to hand off remediation work in priority order.' 'Each public executable remediation wave has a generated CSV, Markdown file, and packaged ZIP.' $publicExecutableRemediationWaveFilesPath
Add-Step $steps 13 'public_executable_remediation_wave_files_validation' 'Validate public executable remediation wave package' $(if ($publicExecutableRemediationWaveFilesValidation) { $publicExecutableRemediationWaveFilesValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveFilesValidation -and $publicExecutableRemediationWaveFilesValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Confirm wave-specific CSV/Markdown files are present, row counts match, and ZIP entries are complete.' 'Validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveFilesValidationPath
Add-Step $steps 14 'public_executable_remediation_wave_signoff' 'Collect public executable remediation wave signoff' $(if ($publicExecutableRemediationWaveSignoff) { $publicExecutableRemediationWaveSignoff.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoff -and $publicExecutableRemediationWaveSignoff.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use the wave signoff CSV to record mitigation or risk acceptance for each remediation wave.' 'Every wave is mitigated or accepted_with_risk and validation has no blockers.' $publicExecutableRemediationWaveSignoffPath
Add-Step $steps 15 'public_executable_remediation_wave_signoff_validation' 'Validate public executable remediation wave signoff fields' $(if ($publicExecutableRemediationWaveSignoffValidation) { $publicExecutableRemediationWaveSignoffValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffValidation -and $publicExecutableRemediationWaveSignoffValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Fill owner, resolved_by, resolved_at, evidence_ref, and risk notes for reviewed waves.' 'Validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveSignoffValidationPath
Add-Step $steps 16 'public_executable_remediation_wave_signoff_operator_pack' 'Use public executable remediation wave signoff operator pack' $(if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffOperatorPack -and $publicExecutableRemediationWaveSignoffOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use the operator pack to hand off pending wave signoff and validation issues to the security owner.' 'Operator pack has no blocked steps and no validation blockers.' $publicExecutableRemediationWaveSignoffOperatorPackPath
Add-Step $steps 17 'public_executable_remediation_wave_signoff_operator_pack_validation' 'Validate public executable remediation wave signoff operator pack' $(if ($publicExecutableRemediationWaveSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffOperatorPackValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffOperatorPackValidation -and $publicExecutableRemediationWaveSignoffOperatorPackValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Confirm operator pack steps, files, counts, and wave coverage are internally consistent.' 'Operator pack validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveSignoffOperatorPackValidationPath
Add-Step $steps 18 'public_executable_remediation_wave_signoff_handoff_pack' 'Package public executable remediation wave signoff handoff' $(if ($publicExecutableRemediationWaveSignoffHandoffPack) { $publicExecutableRemediationWaveSignoffHandoffPack.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffPack -and $publicExecutableRemediationWaveSignoffHandoffPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use the handoff ZIP to give the security owner all wave files, signoff sheets, operator packs, and validations together.' 'Handoff pack exists, has no missing required files, and is ready or pending only on manual wave signoff.' $publicExecutableRemediationWaveSignoffHandoffPackPath
Add-Step $steps 19 'public_executable_remediation_wave_signoff_handoff_pack_validation' 'Validate public executable remediation wave signoff handoff package' $(if ($publicExecutableRemediationWaveSignoffHandoffPackValidation) { $publicExecutableRemediationWaveSignoffHandoffPackValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffPackValidation -and $publicExecutableRemediationWaveSignoffHandoffPackValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Confirm the handoff manifest, CSV, Markdown, required files, and ZIP entries are complete.' 'Handoff package validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveSignoffHandoffPackValidationPath
Add-Step $steps 20 'public_executable_remediation_wave_signoff_handoff_signoff' 'Collect public executable remediation wave signoff handoff receipt' $(if ($publicExecutableRemediationWaveSignoffHandoffSignoff) { $publicExecutableRemediationWaveSignoffHandoffSignoff.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffSignoff -and $publicExecutableRemediationWaveSignoffHandoffSignoff.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use the handoff signoff CSV to record delivery and acceptance of the security handoff ZIP.' 'Handoff package is delivered and accepted or accepted_with_risk by the security owner.' $publicExecutableRemediationWaveSignoffHandoffSignoffPath
Add-Step $steps 21 'public_executable_remediation_wave_signoff_handoff_signoff_validation' 'Validate public executable remediation wave signoff handoff receipt fields' $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffValidation -and $publicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Fill recipient, sent_at, evidence_ref, accepted_by, accepted_at, and required risk notes.' 'Handoff signoff validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveSignoffHandoffSignoffValidationPath
Add-Step $steps 22 'public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' 'Use public executable remediation wave signoff handoff receipt operator pack' $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack -and $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status -eq 'blocked') { 'blocker' } else { 'warning' }) 'Use the operator pack to track delivery, receipt, and field validation for the security handoff ZIP.' 'Handoff receipt operator pack has no blocked steps and no validation blockers.' $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath
Add-Step $steps 23 'public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' 'Validate public executable remediation wave signoff handoff receipt operator pack' $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.overall_status } else { 'missing' }) $(if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation -and $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.blockers -gt 0) { 'blocker' } else { 'warning' }) 'Confirm handoff receipt operator pack steps, files, counts, and signoff coverage are internally consistent.' 'Handoff receipt operator pack validation has zero blockers and zero warnings.' $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath
Add-Step $steps 24 'go_live_security_signoff' 'Collect final security owner signoff' $(if ($goLiveGate -and $goLiveGate.overall_status -eq 'ready') { 'ready' } else { 'not_ready' }) 'warning' 'Review security evidence before final go-live role signoff.' 'security_owner signs or accepts residual risk in final role signoff.' $goLiveGatePath

$blockedSteps = @($steps.ToArray() | Where-Object { $_.severity -eq 'blocker' -and $_.status -ne 'ready' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'open' -or $_.status -eq 'warning' })
$readySteps = @($steps.ToArray() | Where-Object { $_.status -eq 'ready' })

$nextStep = $null
foreach ($step in @($steps.ToArray())) {
    if ($step.status -ne 'ready') { $nextStep = $step; break }
}

$files = @(
    New-FileEntry 'legacy_risk_report' $riskReportPath 'legacy public directory and PHP risk scan'
    New-FileEntry 'attachment_quality' $attachmentQualityPath 'attachment existence and extension quality report'
    New-FileEntry 'security_baseline_doc' $securityBaselinePath 'security baseline checklist'
    New-FileEntry 'acceptance_checklist' $acceptanceChecklistPath 'business and security acceptance checklist'
    New-FileEntry 'nginx_parallel_rollout_example' $nginxParallelConfigPath 'parallel rollout access control example'
    New-FileEntry 'preflight_checklist' $preflightPath 'preflight blockers and warnings'
    New-FileEntry 'go_live_gate' $goLiveGatePath 'go-live gate status'
    New-FileEntry 'security_baseline_signoff' $securitySignoffPath 'manual security baseline mitigation and risk acceptance signoff'
    New-FileEntry 'security_baseline_signoff_validation' $securitySignoffValidationPath 'validation report for security baseline signoff fields'
    New-FileEntry 'public_executable_worklist' $publicExecutableWorklistPath 'operator worklist for public executable files'
    New-FileEntry 'public_executable_worklist_validation' $publicExecutableWorklistValidationPath 'validation report for public executable worklist fields'
    New-FileEntry 'public_executable_remediation_plan' $publicExecutableRemediationPlanPath 'wave-based remediation plan for public executable files'
    New-FileEntry 'public_executable_remediation_plan_validation' $publicExecutableRemediationPlanValidationPath 'validation report for public executable remediation plan'
    New-FileEntry 'public_executable_remediation_wave_files' $publicExecutableRemediationWaveFilesPath 'wave-specific public executable remediation file package manifest'
    New-FileEntry 'public_executable_remediation_wave_files_validation' $publicExecutableRemediationWaveFilesValidationPath 'validation report for public executable remediation wave file package'
    New-FileEntry 'public_executable_remediation_wave_signoff' $publicExecutableRemediationWaveSignoffPath 'manual signoff sheet for public executable remediation waves'
    New-FileEntry 'public_executable_remediation_wave_signoff_validation' $publicExecutableRemediationWaveSignoffValidationPath 'validation report for public executable remediation wave signoff fields'
    New-FileEntry 'public_executable_remediation_wave_signoff_operator_pack' $publicExecutableRemediationWaveSignoffOperatorPackPath 'operator pack for public executable remediation wave signoff'
    New-FileEntry 'public_executable_remediation_wave_signoff_operator_pack_validation' $publicExecutableRemediationWaveSignoffOperatorPackValidationPath 'validation report for public executable remediation wave signoff operator pack'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_pack' $publicExecutableRemediationWaveSignoffHandoffPackPath 'handoff pack for public executable remediation wave signoff'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_pack_validation' $publicExecutableRemediationWaveSignoffHandoffPackValidationPath 'validation report for public executable remediation wave signoff handoff pack'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_signoff' $publicExecutableRemediationWaveSignoffHandoffSignoffPath 'manual receipt signoff for public executable remediation wave signoff handoff pack'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_signoff_validation' $publicExecutableRemediationWaveSignoffHandoffSignoffValidationPath 'validation report for public executable remediation wave signoff handoff signoff fields'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath 'operator pack for public executable remediation wave signoff handoff receipt'
    New-FileEntry 'public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath 'validation report for public executable remediation wave signoff handoff receipt operator pack'
)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This security baseline operator pack summarizes security readiness evidence. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if ($blockedSteps.Count -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_steps = $steps.Count
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
        executable_public_files = $executablePublicFiles
        dangerous_php_patterns = $dangerousPatterns
        infected_or_backup_leftovers = $infectedLeftovers
        attachment_dangerous_extensions = $attachmentDangerous
        attachment_missing_files = $attachmentMissing
        preflight_blockers = if ($preflight) { $preflight.summary.blockers } else { 0 }
        go_live_gate_status = if ($goLiveGate) { $goLiveGate.overall_status } else { 'missing' }
        signoff_status = if ($securitySignoff) { $securitySignoff.overall_status } else { 'missing' }
        signoff_validation_status = if ($securitySignoffValidation) { $securitySignoffValidation.overall_status } else { 'missing' }
        public_executable_worklist_status = if ($publicExecutableWorklist) { $publicExecutableWorklist.overall_status } else { 'missing' }
        public_executable_worklist_items = if ($publicExecutableWorklist) { $publicExecutableWorklist.summary.total_files } else { 0 }
        public_executable_worklist_validation_status = if ($publicExecutableWorklistValidation) { $publicExecutableWorklistValidation.overall_status } else { 'missing' }
        public_executable_worklist_validation_blockers = if ($publicExecutableWorklistValidation) { $publicExecutableWorklistValidation.summary.blockers } else { 0 }
        public_executable_worklist_validation_warnings = if ($publicExecutableWorklistValidation) { $publicExecutableWorklistValidation.summary.warnings } else { 0 }
        public_executable_worklist_pending_files = if ($publicExecutableWorklistValidation) { $publicExecutableWorklistValidation.summary.pending_files } else { 0 }
        public_executable_remediation_plan_status = if ($publicExecutableRemediationPlan) { $publicExecutableRemediationPlan.overall_status } else { 'missing' }
        public_executable_remediation_pending_waves = if ($publicExecutableRemediationPlan) { $publicExecutableRemediationPlan.summary.pending_waves } else { 0 }
        public_executable_remediation_next_wave = if ($publicExecutableRemediationPlan) { $publicExecutableRemediationPlan.summary.next_wave } else { $null }
        public_executable_remediation_plan_validation_status = if ($publicExecutableRemediationPlanValidation) { $publicExecutableRemediationPlanValidation.overall_status } else { 'missing' }
        public_executable_remediation_plan_validation_blockers = if ($publicExecutableRemediationPlanValidation) { $publicExecutableRemediationPlanValidation.summary.blockers } else { 0 }
        public_executable_remediation_plan_validation_warnings = if ($publicExecutableRemediationPlanValidation) { $publicExecutableRemediationPlanValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_files_status = if ($publicExecutableRemediationWaveFiles) { $publicExecutableRemediationWaveFiles.overall_status } else { 'missing' }
        public_executable_remediation_wave_files_zip_exists = if ($publicExecutableRemediationWaveFiles) { $publicExecutableRemediationWaveFiles.summary.zip_exists } else { $false }
        public_executable_remediation_wave_files_zip_size_bytes = if ($publicExecutableRemediationWaveFiles) { $publicExecutableRemediationWaveFiles.summary.zip_size_bytes } else { $null }
        public_executable_remediation_wave_files_validation_status = if ($publicExecutableRemediationWaveFilesValidation) { $publicExecutableRemediationWaveFilesValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_files_validation_blockers = if ($publicExecutableRemediationWaveFilesValidation) { $publicExecutableRemediationWaveFilesValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_files_validation_warnings = if ($publicExecutableRemediationWaveFilesValidation) { $publicExecutableRemediationWaveFilesValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_signoff_status = if ($publicExecutableRemediationWaveSignoff) { $publicExecutableRemediationWaveSignoff.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_pending_items = if ($publicExecutableRemediationWaveSignoff) { $publicExecutableRemediationWaveSignoff.summary.pending_items } else { 0 }
        public_executable_remediation_wave_signoff_validation_status = if ($publicExecutableRemediationWaveSignoffValidation) { $publicExecutableRemediationWaveSignoffValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_validation_blockers = if ($publicExecutableRemediationWaveSignoffValidation) { $publicExecutableRemediationWaveSignoffValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_signoff_validation_warnings = if ($publicExecutableRemediationWaveSignoffValidation) { $publicExecutableRemediationWaveSignoffValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_status = if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_operator_pack_blocked_steps = if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.summary.blocked_steps } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_pending_steps = if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.summary.pending_steps } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_validation_blockers = if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.summary.validation_blockers } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_validation_warnings = if ($publicExecutableRemediationWaveSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffOperatorPack.summary.validation_warnings } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_validation_status = if ($publicExecutableRemediationWaveSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffOperatorPackValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_operator_pack_validation_report_blockers = if ($publicExecutableRemediationWaveSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffOperatorPackValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_signoff_operator_pack_validation_report_warnings = if ($publicExecutableRemediationWaveSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffOperatorPackValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_signoff_handoff_pack_status = if ($publicExecutableRemediationWaveSignoffHandoffPack) { $publicExecutableRemediationWaveSignoffHandoffPack.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_pack_missing_required = if ($publicExecutableRemediationWaveSignoffHandoffPack) { $publicExecutableRemediationWaveSignoffHandoffPack.summary.missing_required } else { 0 }
        public_executable_remediation_wave_signoff_handoff_pack_zip_exists = if ($publicExecutableRemediationWaveSignoffHandoffPack) { $publicExecutableRemediationWaveSignoffHandoffPack.summary.zip_exists } else { $false }
        public_executable_remediation_wave_signoff_handoff_pack_validation_status = if ($publicExecutableRemediationWaveSignoffHandoffPackValidation) { $publicExecutableRemediationWaveSignoffHandoffPackValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_pack_validation_blockers = if ($publicExecutableRemediationWaveSignoffHandoffPackValidation) { $publicExecutableRemediationWaveSignoffHandoffPackValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_signoff_handoff_pack_validation_warnings = if ($publicExecutableRemediationWaveSignoffHandoffPackValidation) { $publicExecutableRemediationWaveSignoffHandoffPackValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_status = if ($publicExecutableRemediationWaveSignoffHandoffSignoff) { $publicExecutableRemediationWaveSignoffHandoffSignoff.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_signoff_pending_items = if ($publicExecutableRemediationWaveSignoffHandoffSignoff) { $publicExecutableRemediationWaveSignoffHandoffSignoff.summary.pending_items } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_validation_status = if ($publicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_signoff_validation_blockers = if ($publicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_validation_warnings = if ($publicExecutableRemediationWaveSignoffHandoffSignoffValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffValidation.summary.warnings } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_status = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_blocked_steps = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.blocked_steps } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_pending_steps = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.summary.pending_steps } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation_status = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.overall_status } else { 'missing' }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation_blockers = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.blockers } else { 0 }
        public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation_warnings = if ($publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation) { $publicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidation.summary.warnings } else { 0 }
    }
    next_step = $nextStep
    files = @($files)
    samples = [ordered]@{
        executable_public_files = @($sections.executable_public_files | Select-Object -First 20)
        dangerous_php_patterns = @($sections.dangerous_php_patterns | Select-Object -First 20)
        infected_or_backup_leftovers = @($sections.infected_or_backup_leftovers | Select-Object -First 20)
    }
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy security baseline operator pack written to $ReportPath"


