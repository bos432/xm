param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff.json"),
    [string]$ValidationPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff-validation.json")
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
Add-Step $steps 1 'Review sampled legacy records' $signoffStatus 'Use the sampling CSV to verify units, projects, attachments, workflow reviews, and workflow logs.' 'Every sample is pass or accepted_with_risk.' $SignoffPath

$validationStatus = if ($validation) { $validation.overall_status } else { 'missing' }
Add-Step $steps 2 'Validate sampling acceptance fields' $validationStatus 'Fix invalid statuses or missing sampled_by, sampled_at, evidence_ref, and risk notes.' 'Validation has zero blockers and zero warnings.' $ValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$issues = if ($validation -and $validation.issues) { @($validation.issues) } else { @() }

$byCategory = @()
foreach ($group in @($items | Group-Object category | Sort-Object Name)) {
    $groupItems = @($group.Group)
    $byCategory += [ordered]@{
        category = $group.Name
        sample_items = $groupItems.Count
        pending_items = @($groupItems | Where-Object { $_.status -eq 'pending' }).Count
        passed_items = @($groupItems | Where-Object { $_.status -eq 'pass' }).Count
        accepted_with_risk_items = @($groupItems | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
        failed_items = @($groupItems | Where-Object { $_.status -eq 'fail' }).Count
        blocked_items = @($groupItems | Where-Object { $_.status -eq 'blocked' }).Count
        sample_keys = @($groupItems | Select-Object -First 8 -ExpandProperty sample_key)
        sources = @($groupItems | ForEach-Object { $_.source } | Where-Object { $_ } | Sort-Object -Unique)
        targets = @($groupItems | ForEach-Object { $_.target } | Where-Object { $_ } | Sort-Object -Unique)
    }
}

$pendingItems = @($items | Where-Object { $_.status -eq 'pending' })
$passedItems = @($items | Where-Object { $_.status -eq 'pass' })
$riskItems = @($items | Where-Object { $_.status -eq 'accepted_with_risk' })
$failedItems = @($items | Where-Object { $_.status -eq 'fail' })
$blockedItems = @($items | Where-Object { $_.status -eq 'blocked' })
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
    note = 'This operator pack summarizes business sampling acceptance. It does not copy files, import records, switch traffic, update templates, update CSV files, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $failedItems.Count -gt 0 -or $blockedItems.Count -gt 0 -or $invalidItems -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingItems.Count -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        sample_items = $items.Count
        category_count = @($byCategory).Count
        pending_items = $pendingItems.Count
        passed_items = $passedItems.Count
        accepted_with_risk_items = $riskItems.Count
        failed_items = $failedItems.Count
        blocked_items = $blockedItems.Count
        invalid_items = $invalidItems
        validation_blockers = $validationBlockers
        validation_warnings = $validationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'sampling_acceptance_csv' (Join-Path $PSScriptRoot 'legacy-migration-sampling-acceptance-signoff.csv') 'business-fillable sampling acceptance CSV'
        New-FileEntry 'sampling_acceptance_signoff' $SignoffPath 'JSON summary of sampling acceptance statuses'
        New-FileEntry 'sampling_acceptance_validation' $ValidationPath 'validation report for manual sampling fields'
    )
    by_category = @($byCategory)
    pending_items = @($pendingItems | Select-Object -First 50)
    validation_issues = @($issues | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration sampling acceptance operator pack written to $ReportPath"
