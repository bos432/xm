param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff.json"),
    [string]$SignoffValidationPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-validation.json"),
    [string]$WaveFilesPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.json"),
    [string]$WaveFilesValidationPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files-validation.json")
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
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [ordered]@{
        key = $key
        path = $path
        file_name = [System.IO.Path]::GetFileName($path)
        purpose = $purpose
        exists = $exists
    }
}

$signoff = Read-JsonReport $SignoffPath
$signoffValidation = Read-JsonReport $SignoffValidationPath
$waveFiles = Read-JsonReport $WaveFilesPath
$waveFilesValidation = Read-JsonReport $WaveFilesValidationPath

$steps = New-Object System.Collections.Generic.List[object]

$waveFilesStatus = if ($waveFiles) { $waveFiles.overall_status } else { 'missing' }
Add-Step $steps 1 'Distribute public executable remediation wave files' $waveFilesStatus 'Use the generated wave CSV/Markdown files and ZIP as the remediation handoff package.' 'Every wave file and the ZIP package exist before collecting signoff.' $WaveFilesPath

$waveFilesValidationStatus = if ($waveFilesValidation) { $waveFilesValidation.overall_status } else { 'missing' }
Add-Step $steps 2 'Validate public executable remediation wave package' $waveFilesValidationStatus 'Regenerate the wave files package if CSV, Markdown, row counts, or ZIP entries are incomplete.' 'Wave package validation has zero blockers and zero warnings.' $WaveFilesValidationPath

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 3 'Collect public executable remediation wave signoff' $signoffStatus 'Use legacy-security-public-executable-remediation-wave-signoff.csv to record mitigation or risk acceptance for each wave.' 'Every wave is mitigated or accepted_with_risk.' $SignoffPath

$signoffValidationStatus = if ($signoffValidation) { $signoffValidation.overall_status } else { 'missing' }
Add-Step $steps 4 'Validate public executable remediation wave signoff fields' $signoffValidationStatus 'Fill owner, resolved_by, resolved_at, evidence_ref, and required notes for reviewed waves.' 'Signoff validation has zero blockers and zero warnings.' $SignoffValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$signoffIssues = if ($signoffValidation -and $signoffValidation.issues) { @($signoffValidation.issues) } else { @() }
$waveFileIssues = if ($waveFilesValidation -and $waveFilesValidation.issues) { @($waveFilesValidation.issues) } else { @() }

$waves = @()
foreach ($item in @($items)) {
    $waves += [ordered]@{
        status = $item.status
        wave = $item.wave
        title = $item.title
        total_files = $item.total_files
        pending_files = $item.pending_files
        blocker_files = $item.blocker_files
        warning_files = $item.warning_files
        owner = $item.owner
        resolved_by = $item.resolved_by
        resolved_at = $item.resolved_at
        evidence_ref = $item.evidence_ref
        source_csv = $item.source_csv
        source_markdown = $item.source_markdown
        acceptance = $item.acceptance
        notes = $item.notes
    }
}

$pendingItems = @($items | Where-Object { $_.status -eq 'pending' }).Count
$mitigatedItems = @($items | Where-Object { $_.status -eq 'mitigated' }).Count
$riskItems = @($items | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$blockedItems = @($items | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = if ($signoff) { $signoff.summary.invalid_items } else { 0 }
$signoffValidationBlockers = @($signoffIssues | Where-Object { $_.severity -eq 'blocker' }).Count
$signoffValidationWarnings = @($signoffIssues | Where-Object { $_.severity -eq 'warning' }).Count
$waveValidationBlockers = @($waveFileIssues | Where-Object { $_.severity -eq 'blocker' }).Count
$waveValidationWarnings = @($waveFileIssues | Where-Object { $_.severity -eq 'warning' }).Count
$validationBlockers = $signoffValidationBlockers + $waveValidationBlockers
$validationWarnings = $signoffValidationWarnings + $waveValidationWarnings

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' })
$readySteps = @($steps.ToArray() | Where-Object { $_.status -eq 'ready' })

$nextStep = $null
foreach ($step in @($steps.ToArray())) {
    if ($step.status -ne 'ready') {
        $nextStep = $step
        break
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This operator pack summarizes public executable remediation wave signoff. It does not delete files, quarantine files, change web server config, copy attachments, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $blockedItems -gt 0 -or $invalidItems -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingItems -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_items = $items.Count
        pending_items = $pendingItems
        mitigated_items = $mitigatedItems
        accepted_with_risk_items = $riskItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        validation_blockers = $validationBlockers
        validation_warnings = $validationWarnings
        signoff_validation_blockers = $signoffValidationBlockers
        signoff_validation_warnings = $signoffValidationWarnings
        wave_package_status = $waveFilesStatus
        wave_package_validation_status = $waveFilesValidationStatus
        wave_package_validation_blockers = $waveValidationBlockers
        wave_package_validation_warnings = $waveValidationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'wave_files' $WaveFilesPath 'wave-specific public executable remediation file package manifest'
        New-FileEntry 'wave_files_zip' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files.zip') 'ZIP package for wave-specific remediation files'
        New-FileEntry 'wave_files_validation' $WaveFilesValidationPath 'validation report for wave-specific remediation files and ZIP contents'
        New-FileEntry 'wave_signoff_csv' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff.csv') 'manual signoff CSV for remediation waves'
        New-FileEntry 'wave_signoff' $SignoffPath 'JSON summary of public executable remediation wave signoff statuses'
        New-FileEntry 'wave_signoff_validation' $SignoffValidationPath 'validation report for remediation wave signoff fields'
    )
    waves = @($waves)
    validation_issues = @(@($waveFileIssues + $signoffIssues) | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff operator pack written to $ReportPath"
