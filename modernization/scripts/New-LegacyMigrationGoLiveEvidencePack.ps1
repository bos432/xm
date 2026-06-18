param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack.md"),
    [string]$ZipPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack.zip")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-EvidenceItem($key, $path, $purpose, $required = $true) {
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [pscustomobject][ordered]@{
        key = $key
        path = $path
        file_name = [System.IO.Path]::GetFileName($path)
        purpose = $purpose
        required = [bool]$required
        exists = $exists
        size_bytes = if ($exists) { (Get-Item -LiteralPath $path).Length } else { $null }
        updated_at = if ($exists) { (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') } else { $null }
    }
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

$goLiveGate = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.json')
$preflight = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json')
$manifest = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json')

$items = New-Object System.Collections.Generic.List[object]
$items.Add((New-EvidenceItem 'go_live_gate' (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.json') 'final go/no-go gate status'))
$items.Add((New-EvidenceItem 'go_live_gate_csv' (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate.csv') 'CSV version of final go/no-go gates'))
$items.Add((New-EvidenceItem 'go_live_gate_validation' (Join-Path $ScriptsRoot 'legacy-migration-go-live-gate-validation.json') 'validation report for go-live gate structure and calculated readiness'))
$items.Add((New-EvidenceItem 'go_live_signoff' (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.json') 'final role signoff report'))
$items.Add((New-EvidenceItem 'go_live_signoff_csv' (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff.csv') 'manual final role signoff CSV'))
$items.Add((New-EvidenceItem 'go_live_signoff_validation' (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-validation.json') 'final role signoff validation report'))
$items.Add((New-EvidenceItem 'go_live_signoff_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack.json') 'operator pack for final go-live role signoff'))
$items.Add((New-EvidenceItem 'go_live_signoff_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-go-live-signoff-operator-pack-validation.json') 'validation report for final go-live role signoff operator pack'))
$items.Add((New-EvidenceItem 'sampling_acceptance_signoff' (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff.json') 'business sampling acceptance signoff report'))
$items.Add((New-EvidenceItem 'sampling_acceptance_signoff_csv' (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff.csv') 'manual business sampling acceptance CSV'))
$items.Add((New-EvidenceItem 'sampling_acceptance_signoff_validation' (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-signoff-validation.json') 'business sampling acceptance validation report'))
$items.Add((New-EvidenceItem 'sampling_acceptance_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack.json') 'operator pack for business sampling acceptance'))
$items.Add((New-EvidenceItem 'sampling_acceptance_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-sampling-acceptance-operator-pack-validation.json') 'validation report for business sampling acceptance operator pack'))
$items.Add((New-EvidenceItem 'workflow_orphan_resolution_signoff' (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff.json') 'manual handling decisions for workflow rows referencing missing legacy projects'))
$items.Add((New-EvidenceItem 'workflow_orphan_resolution_signoff_csv' (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff.csv') 'manual workflow orphan handling CSV'))
$items.Add((New-EvidenceItem 'workflow_orphan_resolution_signoff_validation' (Join-Path $ScriptsRoot 'legacy-workflow-orphan-resolution-signoff-validation.json') 'workflow orphan handling validation report'))
$items.Add((New-EvidenceItem 'workflow_orphan_operator_pack' (Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack.json') 'operator pack for orphan workflow handling decisions'))
$items.Add((New-EvidenceItem 'workflow_orphan_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-workflow-orphan-operator-pack-validation.json') 'validation report for orphan workflow operator pack'))
$items.Add((New-EvidenceItem 'preflight_checklist' (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json') 'preflight blockers and warnings'))
$items.Add((New-EvidenceItem 'preflight_checklist_validation' (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist-validation.json') 'validation report for preflight checklist structure and calculated readiness'))
$items.Add((New-EvidenceItem 'preflight_blocker_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack.json') 'operator pack for preflight blockers and warnings'))
$items.Add((New-EvidenceItem 'preflight_blocker_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack-validation.json') 'validation report for preflight blocker operator pack'))
$items.Add((New-EvidenceItem 'preflight_blocker_operator_pack_csv' (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack.csv') 'CSV version of preflight blocker operator pack'))
$items.Add((New-EvidenceItem 'preflight_blocker_operator_pack_md' (Join-Path $ScriptsRoot 'legacy-migration-preflight-blocker-operator-pack.md') 'Markdown version of preflight blocker operator pack'))
$items.Add((New-EvidenceItem 'blocker_action_sheet' (Join-Path $ScriptsRoot 'legacy-migration-blocker-action-sheet.json') 'migration blocker action sheet'))
$items.Add((New-EvidenceItem 'blocker_action_sheet_validation' (Join-Path $ScriptsRoot 'legacy-migration-blocker-action-sheet-validation.json') 'validation report for migration blocker action sheet'))
$items.Add((New-EvidenceItem 'blocker_resolution_pack' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-pack.json') 'blocked stage resolution plan'))
$items.Add((New-EvidenceItem 'blocker_resolution_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-pack-validation.json') 'validation report for blocker resolution pack structure'))
$items.Add((New-EvidenceItem 'blocker_resolution_signoff' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff.json') 'blocked stage approval execution verification signoff'))
$items.Add((New-EvidenceItem 'blocker_resolution_signoff_validation' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-signoff-validation.json') 'blocked stage signoff validation report'))
$items.Add((New-EvidenceItem 'blocker_resolution_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack.json') 'operator pack for blocker resolution approval execution verification'))
$items.Add((New-EvidenceItem 'blocker_resolution_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack-validation.json') 'validation report for blocker resolution operator pack'))
$items.Add((New-EvidenceItem 'resolution_acceptance_gate' (Join-Path $ScriptsRoot 'legacy-migration-resolution-acceptance-gate.json') 'mapping and resolved dry-run acceptance gate'))
$items.Add((New-EvidenceItem 'resolution_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack.json') 'operator workflow summary for mapping resolution'))
$items.Add((New-EvidenceItem 'resolution_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-resolution-operator-pack-validation.json') 'validation report for resolution mapping operator pack'))
$items.Add((New-EvidenceItem 'dry_run_comparison' (Join-Path $ScriptsRoot 'legacy-migration-dry-run-comparison.json') 'default resolved and mock dry-run comparison'))
$items.Add((New-EvidenceItem 'workflow_db_dry_run' (Join-Path $ScriptsRoot 'legacy-workflow-db-dry-run.json') 'workflow review and operation log row-level preview'))
$items.Add((New-EvidenceItem 'batch_plan' (Join-Path $ScriptsRoot 'legacy-migration-batch-plan.json') 'migration batch dependency plan'))
$items.Add((New-EvidenceItem 'readiness_summary' (Join-Path $ScriptsRoot 'legacy-migration-readiness-summary.json') 'migration readiness summary'))
$items.Add((New-EvidenceItem 'artifact_manifest' (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json') 'artifact completeness manifest'))
$items.Add((New-EvidenceItem 'artifact_manifest_validation' (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest-validation.json') 'validation report for artifact manifest structure and counts'))
$items.Add((New-EvidenceItem 'go_live_drill_report' (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-report.md') 'go-live drill report template'))
$items.Add((New-EvidenceItem 'go_live_drill_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack.json') 'operator pack for go-live drill readiness'))
$items.Add((New-EvidenceItem 'go_live_drill_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack-validation.json') 'validation report for go-live drill operator pack'))
$items.Add((New-EvidenceItem 'rollback_plan' (Join-Path $ScriptsRoot 'legacy-migration-rollback-plan.md') 'rollback plan template'))
$items.Add((New-EvidenceItem 'operator_runbook' (Join-Path $ScriptsRoot 'legacy-migration-operator-runbook.md') 'operator runbook'))
$items.Add((New-EvidenceItem 'operational_docs_validation' (Join-Path $ScriptsRoot 'legacy-migration-operational-docs-validation.json') 'validation report for go-live drill report, rollback plan, and operator runbook'))
$items.Add((New-EvidenceItem 'attachment_exception_operator_pack' (Join-Path $ScriptsRoot 'legacy-attachment-exception-operator-pack.json') 'operator pack for missing attachment exception workflow'))
$items.Add((New-EvidenceItem 'attachment_exception_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-attachment-exception-operator-pack-validation.json') 'validation report for missing attachment exception operator pack'))
$items.Add((New-EvidenceItem 'next_actions' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.json') 'prioritized open action report'))
$items.Add((New-EvidenceItem 'next_actions_csv' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.csv') 'CSV version of prioritized open action report'))
$items.Add((New-EvidenceItem 'next_actions_md' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.md') 'markdown version of prioritized open action report'))
$items.Add((New-EvidenceItem 'next_actions_blockers_csv' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.blockers.csv') 'CSV version of blocker-only open action report'))
$items.Add((New-EvidenceItem 'next_actions_blockers_md' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.blockers.md') 'markdown version of blocker-only open action report'))
$items.Add((New-EvidenceItem 'next_actions_validation' (Join-Path $ScriptsRoot 'legacy-migration-next-actions-validation.json') 'validation report for prioritized open action report'))
$items.Add((New-EvidenceItem 'next_actions_owner_files' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-files.json') 'manifest of owner-specific next action files'))
$items.Add((New-EvidenceItem 'next_actions_owner_files_zip' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-files.zip') 'ZIP package of owner-specific next action files'))
$items.Add((New-EvidenceItem 'next_actions_owner_files_validation' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-files-validation.json') 'validation report for owner-specific next action files and ZIP contents'))
$items.Add((New-EvidenceItem 'next_actions_owner_signoff' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff.json') 'manual signoff report for owner-specific next action handoff'))
$items.Add((New-EvidenceItem 'next_actions_owner_signoff_csv' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff.csv') 'manual signoff CSV for owner-specific next action handoff'))
$items.Add((New-EvidenceItem 'next_actions_owner_signoff_validation' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-validation.json') 'validation report for owner-specific next action handoff signoff fields'))
$items.Add((New-EvidenceItem 'next_actions_owner_signoff_operator_pack' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-operator-pack.json') 'operator pack for owner-specific next action handoff signoff'))
$items.Add((New-EvidenceItem 'next_actions_owner_signoff_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-signoff-operator-pack-validation.json') 'validation report for owner-specific next action handoff signoff operator pack'))
$items.Add((New-EvidenceItem 'risk_report' (Join-Path $ScriptsRoot 'legacy-risk-report.txt') 'legacy public directory risk scan'))
$items.Add((New-EvidenceItem 'security_baseline_operator_pack' (Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack.json') 'operator pack for legacy security baseline review'))
$items.Add((New-EvidenceItem 'security_baseline_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack-validation.json') 'validation report for legacy security baseline operator pack'))
$items.Add((New-EvidenceItem 'security_baseline_signoff' (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.json') 'manual security baseline mitigation and risk acceptance signoff'))
$items.Add((New-EvidenceItem 'security_baseline_signoff_csv' (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.csv') 'manual security baseline signoff CSV'))
$items.Add((New-EvidenceItem 'security_baseline_signoff_validation' (Join-Path $ScriptsRoot 'legacy-security-baseline-signoff-validation.json') 'security baseline signoff field validation'))
$items.Add((New-EvidenceItem 'security_public_executable_worklist' (Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist.json') 'operator worklist for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_worklist_csv' (Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist.csv') 'CSV operator worklist for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_worklist_md' (Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist.md') 'Markdown operator worklist for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_worklist_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-worklist-validation.json') 'validation report for public executable worklist fields'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_plan' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan.json') 'wave-based remediation plan for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_plan_csv' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan.csv') 'CSV wave-based remediation plan for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_plan_md' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan.md') 'Markdown wave-based remediation plan for public executable files'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_plan_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-plan-validation.json') 'validation report for public executable remediation plan coverage and wave counts'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_files' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files.json') 'manifest for wave-specific public executable remediation files'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_files_zip' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files.zip') 'ZIP package for wave-specific public executable remediation files'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_files_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-files-validation.json') 'validation report for wave-specific public executable remediation files and ZIP contents'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff.json') 'manual signoff sheet for public executable remediation waves'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_csv' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff.csv') 'manual signoff CSV for public executable remediation waves'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-validation.json') 'validation report for public executable remediation wave signoff fields'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_operator_pack' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json') 'operator pack for public executable remediation wave signoff'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json') 'validation report for public executable remediation wave signoff operator pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_pack' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json') 'handoff pack for public executable remediation wave signoff'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_pack_csv' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.csv') 'CSV manifest for public executable remediation wave signoff handoff pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_pack_md' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.md') 'Markdown manifest for public executable remediation wave signoff handoff pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_pack_zip' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip') 'ZIP package for public executable remediation wave signoff handoff'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_pack_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json') 'validation report for public executable remediation wave signoff handoff pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_signoff' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json') 'manual receipt signoff for public executable remediation wave signoff handoff pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_signoff_csv' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv') 'manual receipt signoff CSV for public executable remediation wave signoff handoff pack'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_signoff_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json') 'validation report for public executable remediation wave signoff handoff signoff fields'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json') 'operator pack for public executable remediation wave signoff handoff receipt'))
$items.Add((New-EvidenceItem 'security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' (Join-Path $ScriptsRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json') 'validation report for public executable remediation wave signoff handoff receipt operator pack'))

$ownerFiles = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-next-actions.owner-files.json')
if ($ownerFiles -and $ownerFiles.files) {
    foreach ($ownerFile in @($ownerFiles.files)) {
        $slug = if ($ownerFile.slug) { $ownerFile.slug } else { 'unassigned' }
        $items.Add((New-EvidenceItem "next_actions_owner_${slug}_csv" $ownerFile.csv "owner-specific next action CSV for $($ownerFile.owner)"))
        $items.Add((New-EvidenceItem "next_actions_owner_${slug}_md" $ownerFile.markdown "owner-specific next action Markdown for $($ownerFile.owner)"))
        if ($ownerFile.blocker_csv) {
            $items.Add((New-EvidenceItem "next_actions_owner_${slug}_blockers_csv" $ownerFile.blocker_csv "owner-specific blocker action CSV for $($ownerFile.owner)"))
        }
        if ($ownerFile.blocker_markdown) {
            $items.Add((New-EvidenceItem "next_actions_owner_${slug}_blockers_md" $ownerFile.blocker_markdown "owner-specific blocker action Markdown for $($ownerFile.owner)"))
        }
    }
}

$missingRequired = @($items.ToArray() | Where-Object { $_.required -and -not $_.exists })
$existingRequired = @($items.ToArray() | Where-Object { $_.required -and $_.exists })

@($items.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Migration Go-Live Evidence Pack'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines 'This evidence pack is preview-only. It packages generated reports for offline review and does not copy legacy attachments, import records, switch traffic, update templates, or write database records.'
Add-Line $lines
Add-Line $lines '## Summary'
Add-Line $lines
Add-Line $lines ('- Go-live gate status: ' + $(if ($goLiveGate) { $goLiveGate.overall_status } else { 'missing' }))
Add-Line $lines ('- Write cutover ready: ' + $(if ($goLiveGate) { [string]$goLiveGate.write_cutover_ready } else { 'False' }))
Add-Line $lines ('- Preflight status: ' + $(if ($preflight) { $preflight.overall_status } else { 'missing' }))
Add-Line $lines ('- Manifest missing required: ' + $(if ($manifest) { $manifest.summary.missing_required } else { 'missing' }))
Add-Line $lines ('- Evidence files: ' + $items.Count)
Add-Line $lines ('- Missing required evidence files: ' + $missingRequired.Count)
Add-Line $lines
Add-Line $lines '## Files'
Add-Line $lines
Add-Line $lines '| Key | Required | Exists | Size | File | Purpose |'
Add-Line $lines '| --- | --- | --- | ---: | --- | --- |'
foreach ($item in @($items.ToArray())) {
    Add-Line $lines "| $($item.key) | $($item.required) | $($item.exists) | $($item.size_bytes) | $($item.file_name) | $($item.purpose) |"
}
Add-Line $lines
Add-Line $lines '## Review Rule'
Add-Line $lines
Add-Line $lines 'The evidence pack is sufficient for offline review only when all required evidence files exist and the go-live gate is ready.'
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $ZipPath -Force
}

$zipInputs = New-Object System.Collections.Generic.List[string]
foreach ($item in @($items.ToArray())) {
    if ($item.exists) { $zipInputs.Add($item.path) }
}
$zipInputs.Add($CsvPath)
$zipInputs.Add($MarkdownPath)

if ($zipInputs.Count -gt 0) {
    Compress-Archive -LiteralPath @($zipInputs.ToArray()) -DestinationPath $ZipPath -Force
}

$zipExists = Test-Path -LiteralPath $ZipPath -PathType Leaf
$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This evidence pack packages generated go-live review artifacts. It does not copy legacy attachments, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($missingRequired.Count -gt 0) { 'blocked' } elseif (-not $goLiveGate -or $goLiveGate.overall_status -ne 'ready') { 'not_ready' } else { 'ready' }
    write_cutover_ready = if ($goLiveGate) { [bool]$goLiveGate.write_cutover_ready } else { $false }
    summary = [ordered]@{
        evidence_files = $items.Count
        existing_required = $existingRequired.Count
        missing_required = $missingRequired.Count
        go_live_gate_status = if ($goLiveGate) { $goLiveGate.overall_status } else { 'missing' }
        preflight_status = if ($preflight) { $preflight.overall_status } else { 'missing' }
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $ZipPath).Length } else { $null }
    }
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
        zip = $ZipPath
    }
    missing_required = @($missingRequired | ForEach-Object { $_.key })
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live evidence pack written to $ReportPath"
Write-Host "Legacy migration go-live evidence pack ZIP written to $ZipPath"

