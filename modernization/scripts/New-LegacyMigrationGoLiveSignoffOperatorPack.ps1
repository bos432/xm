param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff.json"),
    [string]$ValidationPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff-validation.json")
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

$signoff = Read-JsonReport $SignoffPath
$validation = Read-JsonReport $ValidationPath

$steps = New-Object System.Collections.Generic.List[object]

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 1 'Collect final go-live role signoff' $signoffStatus 'Use legacy-migration-go-live-signoff.csv to collect technical, operations, business, and security signoff.' 'Every role is signed or accepted_with_risk.' $SignoffPath

$validationStatus = if ($validation) { $validation.overall_status } else { 'missing' }
Add-Step $steps 2 'Validate final signoff fields' $validationStatus 'Fix invalid statuses or missing owner, signed_by, signed_at, and risk notes.' 'Validation has zero blockers and zero warnings.' $ValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$issues = if ($validation -and $validation.issues) { @($validation.issues) } else { @() }

$roles = @()
foreach ($item in @($items)) {
    $roles += [ordered]@{
        role_key = $item.role_key
        role_name = $item.role_name
        status = $item.status
        owner = $item.owner
        confirmation = $item.confirmation
        evidence = $item.evidence
        signed_by = $item.signed_by
        signed_at = $item.signed_at
        notes = $item.notes
    }
}

$pendingItems = @($items | Where-Object { $_.status -eq 'pending' }).Count
$signedItems = @($items | Where-Object { $_.status -eq 'signed' }).Count
$riskItems = @($items | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$rejectedItems = @($items | Where-Object { $_.status -eq 'rejected' }).Count
$invalidItems = if ($signoff) { $signoff.summary.invalid_items } else { 0 }
$validationBlockers = @($issues | Where-Object { $_.severity -eq 'blocker' }).Count
$validationWarnings = @($issues | Where-Object { $_.severity -eq 'warning' }).Count

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
    note = 'This operator pack summarizes final go-live role signoff. It does not sign roles, copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $rejectedItems -gt 0 -or $invalidItems -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingItems -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_items = $items.Count
        pending_items = $pendingItems
        signed_items = $signedItems
        accepted_with_risk_items = $riskItems
        rejected_items = $rejectedItems
        invalid_items = $invalidItems
        validation_blockers = $validationBlockers
        validation_warnings = $validationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'go_live_signoff_csv' (Join-Path $PSScriptRoot 'legacy-migration-go-live-signoff.csv') 'manual final role signoff CSV'
        New-FileEntry 'go_live_signoff' $SignoffPath 'JSON summary of final role signoff statuses'
        New-FileEntry 'go_live_signoff_validation' $ValidationPath 'validation report for final role signoff fields'
        New-FileEntry 'go_live_gate' (Join-Path $PSScriptRoot 'legacy-migration-go-live-gate.json') 'final go/no-go gate report'
        New-FileEntry 'evidence_pack' (Join-Path $PSScriptRoot 'legacy-migration-go-live-evidence-pack.zip') 'offline evidence package for final approval'
    )
    roles = @($roles)
    validation_issues = @($issues | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live signoff operator pack written to $ReportPath"
