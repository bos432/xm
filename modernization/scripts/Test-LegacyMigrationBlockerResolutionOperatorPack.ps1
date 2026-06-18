param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-operator-pack.json"),
    [string]$ResolutionPackPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff.json")
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
$resolutionPack = Read-JsonReport $ResolutionPackPath
$signoff = Read-JsonReport $SignoffPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'open', 'pending', 'approved', 'executed', 'verified')
$requiredFileKeys = @(
    'blocker_resolution_pack',
    'blocker_resolution_pack_csv',
    'blocker_resolution_pack_md',
    'blocker_resolution_signoff_csv',
    'blocker_resolution_signoff',
    'blocker_resolution_signoff_validation'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'blocker resolution operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $stages = @($operatorPack.stages)
    $operatorFiles = @($operatorPack.operator_files)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 3) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 3 steps, found $($steps.Count)."
    }

    $duplicateOrders = @($steps | Group-Object order | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    foreach ($order in $duplicateOrders) {
        Add-Issue $issues 'blocker' 'steps.order' 'duplicate_step_order' "operator pack contains duplicate step order: $order."
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
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'open' -or $_.status -eq 'pending' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' }).Count
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' 'summary ready_steps does not match step statuses.' }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' 'summary pending_steps does not match step statuses.' }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' 'summary blocked_steps does not match step statuses.' }

    $pendingItems = @($stages | Where-Object { $_.signoff_status -eq 'pending' }).Count
    $approvedItems = @($stages | Where-Object { $_.signoff_status -eq 'approved' }).Count
    $executedItems = @($stages | Where-Object { $_.signoff_status -eq 'executed' }).Count
    $verifiedItems = @($stages | Where-Object { $_.signoff_status -eq 'verified' }).Count
    $blockedItems = @($stages | Where-Object { $_.signoff_status -eq 'blocked' }).Count
    if ([int]$summary.pending_items -ne $pendingItems) { Add-Issue $issues 'blocker' 'summary.pending_items' 'pending_item_count_mismatch' 'summary pending_items does not match stage signoff statuses.' }
    if ([int]$summary.approved_items -ne $approvedItems) { Add-Issue $issues 'blocker' 'summary.approved_items' 'approved_item_count_mismatch' 'summary approved_items does not match stage signoff statuses.' }
    if ([int]$summary.executed_items -ne $executedItems) { Add-Issue $issues 'blocker' 'summary.executed_items' 'executed_item_count_mismatch' 'summary executed_items does not match stage signoff statuses.' }
    if ([int]$summary.verified_items -ne $verifiedItems) { Add-Issue $issues 'blocker' 'summary.verified_items' 'verified_item_count_mismatch' 'summary verified_items does not match stage signoff statuses.' }
    if ([int]$summary.blocked_items -ne $blockedItems) { Add-Issue $issues 'blocker' 'summary.blocked_items' 'blocked_item_count_mismatch' 'summary blocked_items does not match stage signoff statuses.' }

    if ($resolutionPack -and [int]$summary.blocked_stages -ne [int]$resolutionPack.summary.blocked_stages) {
        Add-Issue $issues 'blocker' 'summary.blocked_stages' 'blocked_stage_count_mismatch' 'summary blocked_stages does not match blocker resolution pack.'
    }
    if ($signoff -and [int]$summary.signoff_items -ne [int]$signoff.summary.signoff_items) {
        Add-Issue $issues 'blocker' 'summary.signoff_items' 'signoff_item_count_mismatch' 'summary signoff_items does not match blocker resolution signoff.'
    }

    $expectedStatus = if ($blockedStepCount -gt 0 -or [int]$summary.blocked_items -gt 0 -or [int]$summary.invalid_items -gt 0 -or [int]$summary.validation_blockers -gt 0) { 'blocked' } elseif ($pendingStepCount -gt 0 -or [int]$summary.pending_items -gt 0 -or [int]$summary.approved_items -gt 0 -or [int]$summary.executed_items -gt 0 -or [int]$summary.validation_warnings -gt 0) { 'not_ready' } else { 'ready' }
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
    note = 'This report validates the blocker resolution operator pack structure and internal counts. It does not copy files, import records, update templates, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        stages = if ($operatorPack) { @($operatorPack.stages).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker resolution operator pack validation written to $ReportPath"
