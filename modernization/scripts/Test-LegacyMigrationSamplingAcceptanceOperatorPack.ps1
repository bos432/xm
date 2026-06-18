param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        field = $field
        code = $code
        message = $message
    })
}

$operatorPack = Read-JsonReport $OperatorPackPath
$signoff = Read-JsonReport $SignoffPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'open', 'pending', 'pass', 'accepted_with_risk', 'fail')
$requiredFileKeys = @(
    'sampling_acceptance_csv',
    'sampling_acceptance_signoff',
    'sampling_acceptance_validation'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'sampling acceptance operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $operatorFiles = @($operatorPack.operator_files)
    $categories = @($operatorPack.by_category)
    $pendingItems = @($operatorPack.pending_items)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 2) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 2 steps, found $($steps.Count)."
    }

    foreach ($step in $steps) {
        if (Test-Blank $step.title) { Add-Issue $issues 'warning' 'steps.title' 'blank_step_title' "step $($step.order) title is blank." }
        if (Test-Blank $step.action) { Add-Issue $issues 'warning' 'steps.action' 'blank_step_action' "step $($step.order) action is blank." }
        if (Test-Blank $step.acceptance) { Add-Issue $issues 'warning' 'steps.acceptance' 'blank_step_acceptance' "step $($step.order) acceptance is blank." }
        if ($validStatuses -notcontains $step.status) {
            Add-Issue $issues 'blocker' 'steps.status' 'invalid_step_status' "step $($step.order) has invalid status: $($step.status)."
        }
    }

    $fileKeys = @($operatorFiles | ForEach-Object { $_.key })
    foreach ($key in $requiredFileKeys) {
        if ($fileKeys -notcontains $key) {
            Add-Issue $issues 'blocker' 'operator_files' 'missing_operator_file_key' "operator_files is missing required key: $key."
        }
    }

    foreach ($file in $operatorFiles) {
        if (Test-Blank $file.path) {
            Add-Issue $issues 'blocker' 'operator_files.path' 'blank_operator_file_path' "operator file $($file.key) path is blank."
        } elseif (-not (Test-Path -LiteralPath $file.path -PathType Leaf)) {
            Add-Issue $issues 'blocker' 'operator_files.path' 'missing_operator_file' "operator file $($file.key) is missing: $($file.path)."
        }
    }

    $readyStepCount = @($steps | Where-Object { $_.status -eq 'ready' }).Count
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' }).Count
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' 'summary ready_steps does not match step statuses.' }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' 'summary pending_steps does not match step statuses.' }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' 'summary blocked_steps does not match step statuses.' }
    if ([int]$summary.category_count -ne $categories.Count) { Add-Issue $issues 'blocker' 'summary.category_count' 'category_count_mismatch' 'summary category_count does not match by_category rows.' }

    $categorySampleCount = 0
    $categoryPendingCount = 0
    $categoryPassedCount = 0
    $categoryRiskCount = 0
    $categoryFailedCount = 0
    $categoryBlockedCount = 0
    foreach ($category in $categories) {
        if (Test-Blank $category.category) { Add-Issue $issues 'warning' 'by_category.category' 'blank_category' 'category key is blank.' }
        $categorySampleCount += [int]$category.sample_items
        $categoryPendingCount += [int]$category.pending_items
        $categoryPassedCount += [int]$category.passed_items
        $categoryRiskCount += [int]$category.accepted_with_risk_items
        $categoryFailedCount += [int]$category.failed_items
        $categoryBlockedCount += [int]$category.blocked_items
    }

    if ([int]$summary.sample_items -ne $categorySampleCount) { Add-Issue $issues 'blocker' 'summary.sample_items' 'sample_item_count_mismatch' 'summary sample_items does not match category totals.' }
    if ([int]$summary.pending_items -ne $categoryPendingCount) { Add-Issue $issues 'blocker' 'summary.pending_items' 'pending_item_count_mismatch' 'summary pending_items does not match category totals.' }
    if ([int]$summary.passed_items -ne $categoryPassedCount) { Add-Issue $issues 'blocker' 'summary.passed_items' 'passed_item_count_mismatch' 'summary passed_items does not match category totals.' }
    if ([int]$summary.accepted_with_risk_items -ne $categoryRiskCount) { Add-Issue $issues 'blocker' 'summary.accepted_with_risk_items' 'risk_item_count_mismatch' 'summary accepted_with_risk_items does not match category totals.' }
    if ([int]$summary.failed_items -ne $categoryFailedCount) { Add-Issue $issues 'blocker' 'summary.failed_items' 'failed_item_count_mismatch' 'summary failed_items does not match category totals.' }
    if ([int]$summary.blocked_items -ne $categoryBlockedCount) { Add-Issue $issues 'blocker' 'summary.blocked_items' 'blocked_item_count_mismatch' 'summary blocked_items does not match category totals.' }

    if ($signoff -and [int]$signoff.summary.sample_items -ne [int]$summary.sample_items) {
        Add-Issue $issues 'blocker' 'summary.sample_items' 'source_signoff_count_mismatch' 'operator sample count does not match source signoff sample count.'
    }

    if ($pendingItems.Count -gt [int]$summary.pending_items) {
        Add-Issue $issues 'blocker' 'pending_items' 'pending_sample_overflow' 'operator pack pending_items contains more rows than summary pending_items.'
    }

    $expectedStatus = if ($blockedStepCount -gt 0 -or [int]$summary.failed_items -gt 0 -or [int]$summary.blocked_items -gt 0 -or [int]$summary.invalid_items -gt 0 -or [int]$summary.validation_blockers -gt 0) { 'blocked' } elseif ($pendingStepCount -gt 0 -or [int]$summary.pending_items -gt 0 -or [int]$summary.validation_warnings -gt 0) { 'not_ready' } else { 'ready' }
    if ($operatorPack.overall_status -ne $expectedStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "operator pack overall_status should be $expectedStatus based on summary counts."
    }

    $firstOpenStep = @($steps | Where-Object { $_.status -ne 'ready' } | Select-Object -First 1)
    if ($firstOpenStep.Count -gt 0) {
        if (-not $operatorPack.next_step -or [int]$operatorPack.next_step.order -ne [int]$firstOpenStep[0].order) {
            Add-Issue $issues 'blocker' 'next_step' 'next_step_mismatch' 'operator pack next_step does not match the first non-ready step.'
        }
    } elseif ($operatorPack.next_step) {
        Add-Issue $issues 'warning' 'next_step' 'unexpected_next_step' 'operator pack has a next_step even though all steps are ready.'
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the sampling acceptance operator pack structure, required files, and internal counts. It does not approve samples, copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        categories = if ($operatorPack) { @($operatorPack.by_category).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration sampling acceptance operator pack validation written to $ReportPath"
