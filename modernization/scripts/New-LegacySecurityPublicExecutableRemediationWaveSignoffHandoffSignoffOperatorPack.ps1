param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json"),
    [string]$HandoffPackPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json"),
    [string]$HandoffValidationPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json"),
    [string]$SignoffValidationPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json")
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

$handoffPack = Read-JsonReport $HandoffPackPath
$handoffValidation = Read-JsonReport $HandoffValidationPath
$signoff = Read-JsonReport $SignoffPath
$signoffValidation = Read-JsonReport $SignoffValidationPath

$steps = New-Object System.Collections.Generic.List[object]

$handoffStatus = if ($handoffPack) { $handoffPack.overall_status } else { 'missing' }
Add-Step $steps 1 'Prepare public executable remediation handoff package' $handoffStatus 'Use the generated handoff ZIP as the single package for security owner review.' 'Handoff pack exists and has no missing required files.' $HandoffPackPath

$handoffValidationStatus = if ($handoffValidation) { $handoffValidation.overall_status } else { 'missing' }
Add-Step $steps 2 'Validate public executable remediation handoff package' $handoffValidationStatus 'Regenerate the handoff pack if required files or ZIP entries are incomplete.' 'Handoff pack validation has zero blockers and zero warnings.' $HandoffValidationPath

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 3 'Collect public executable remediation handoff receipt' $signoffStatus 'Use the handoff signoff CSV to record delivery and acceptance of the handoff ZIP.' 'Handoff receipt is accepted or accepted_with_risk.' $SignoffPath

$signoffValidationStatus = if ($signoffValidation) { $signoffValidation.overall_status } else { 'missing' }
Add-Step $steps 4 'Validate public executable remediation handoff receipt fields' $signoffValidationStatus 'Fill recipient, sent_at, evidence_ref, accepted_by, accepted_at, and risk notes when required.' 'Handoff receipt validation has zero blockers and zero warnings.' $SignoffValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$signoffIssues = if ($signoffValidation -and $signoffValidation.issues) { @($signoffValidation.issues) } else { @() }
$handoffIssues = if ($handoffValidation -and $handoffValidation.issues) { @($handoffValidation.issues) } else { @() }

$pendingItems = @($items | Where-Object { $_.status -eq 'pending' }).Count
$deliveredItems = @($items | Where-Object { $_.status -eq 'delivered' }).Count
$acceptedItems = @($items | Where-Object { $_.status -eq 'accepted' }).Count
$riskItems = @($items | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$blockedItems = @($items | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = if ($signoff) { $signoff.summary.invalid_items } else { 0 }
$handoffValidationBlockers = @($handoffIssues | Where-Object { $_.severity -eq 'blocker' }).Count
$handoffValidationWarnings = @($handoffIssues | Where-Object { $_.severity -eq 'warning' }).Count
$signoffValidationBlockers = @($signoffIssues | Where-Object { $_.severity -eq 'blocker' }).Count
$signoffValidationWarnings = @($signoffIssues | Where-Object { $_.severity -eq 'warning' }).Count
$validationBlockers = $handoffValidationBlockers + $signoffValidationBlockers
$validationWarnings = $handoffValidationWarnings + $signoffValidationWarnings

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
    note = 'This operator pack summarizes public executable remediation handoff receipt signoff. It does not sign receipts, delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $blockedItems -gt 0 -or $invalidItems -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingItems -gt 0 -or $deliveredItems -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_items = $items.Count
        pending_items = $pendingItems
        delivered_items = $deliveredItems
        accepted_items = $acceptedItems
        accepted_with_risk_items = $riskItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        handoff_pack_status = $handoffStatus
        handoff_pack_missing_required = if ($handoffPack) { $handoffPack.summary.missing_required } else { 0 }
        handoff_pack_zip_exists = if ($handoffPack) { $handoffPack.summary.zip_exists } else { $false }
        validation_blockers = $validationBlockers
        validation_warnings = $validationWarnings
        handoff_validation_blockers = $handoffValidationBlockers
        handoff_validation_warnings = $handoffValidationWarnings
        signoff_validation_blockers = $signoffValidationBlockers
        signoff_validation_warnings = $signoffValidationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'handoff_pack' $HandoffPackPath 'handoff pack manifest for public executable remediation wave signoff'
        New-FileEntry 'handoff_pack_zip' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip') 'handoff ZIP package for security owner review'
        New-FileEntry 'handoff_pack_validation' $HandoffValidationPath 'validation report for handoff pack files and ZIP contents'
        New-FileEntry 'handoff_signoff_csv' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv') 'manual receipt signoff CSV for the handoff package'
        New-FileEntry 'handoff_signoff' $SignoffPath 'JSON summary of handoff receipt signoff status'
        New-FileEntry 'handoff_signoff_validation' $SignoffValidationPath 'validation report for handoff receipt signoff fields'
    )
    signoff_items = @($items)
    validation_issues = @(@($handoffIssues + $signoffIssues) | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff handoff signoff operator pack written to $ReportPath"
