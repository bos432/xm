param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-baseline-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-security-baseline-operator-pack.json")
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
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'pending', 'open', 'warning')
$validSeverities = @('blocker', 'warning', 'info')

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'security baseline operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $files = @($operatorPack.files)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -eq 0) {
        Add-Issue $issues 'blocker' 'steps' 'missing_steps' 'operator pack has no steps.'
    }

    if ($files.Count -eq 0) {
        Add-Issue $issues 'blocker' 'files' 'missing_files' 'operator pack has no file entries.'
    }

    $duplicateOrders = @($steps | Group-Object order | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    foreach ($order in $duplicateOrders) {
        Add-Issue $issues 'blocker' 'steps.order' 'duplicate_step_order' "operator pack contains duplicate step order: $order."
    }

    foreach ($step in $steps) {
        if (Test-Blank $step.category) { Add-Issue $issues 'warning' 'steps.category' 'blank_step_category' "step $($step.order) category is blank." }
        if (Test-Blank $step.title) { Add-Issue $issues 'warning' 'steps.title' 'blank_step_title' "step $($step.order) title is blank." }
        if (Test-Blank $step.action) { Add-Issue $issues 'warning' 'steps.action' 'blank_step_action' "step $($step.order) action is blank." }
        if (Test-Blank $step.acceptance) { Add-Issue $issues 'warning' 'steps.acceptance' 'blank_step_acceptance' "step $($step.order) acceptance is blank." }
        if ($validStatuses -notcontains $step.status) {
            Add-Issue $issues 'blocker' 'steps.status' 'invalid_step_status' "step $($step.order) has invalid status: $($step.status)."
        }
        if ($validSeverities -notcontains $step.severity) {
            Add-Issue $issues 'blocker' 'steps.severity' 'invalid_step_severity' "step $($step.order) has invalid severity: $($step.severity)."
        }
    }

    foreach ($file in $files) {
        if (Test-Blank $file.key) { Add-Issue $issues 'warning' 'files.key' 'blank_file_key' 'operator file entry key is blank.' }
        if (Test-Blank $file.path) {
            Add-Issue $issues 'blocker' 'files.path' 'blank_file_path' "operator file $($file.key) path is blank."
        } elseif ($file.required -and -not (Test-Path -LiteralPath $file.path -PathType Leaf)) {
            Add-Issue $issues 'blocker' 'files.path' 'missing_required_file' "required operator file $($file.key) is missing: $($file.path)."
        }
    }

    $readyStepCount = @($steps | Where-Object { $_.status -eq 'ready' }).Count
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' -or $_.status -eq 'warning' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.severity -eq 'blocker' -and $_.status -ne 'ready' }).Count
    if ([int]$summary.total_steps -ne $steps.Count) { Add-Issue $issues 'blocker' 'summary.total_steps' 'total_step_count_mismatch' 'summary total_steps does not match steps count.' }
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' 'summary ready_steps does not match step statuses.' }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' 'summary pending_steps does not match step statuses.' }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' 'summary blocked_steps does not match blocker step statuses.' }

    $expectedStatus = if ($blockedStepCount -gt 0) { 'blocked' } elseif ($pendingStepCount -gt 0) { 'not_ready' } else { 'ready' }
    if ($operatorPack.overall_status -ne $expectedStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "operator pack overall_status should be $expectedStatus based on step counts."
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
    note = 'This report validates the security baseline operator pack structure and internal counts. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        files = if ($operatorPack) { @($operatorPack.files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy security baseline operator pack validation written to $ReportPath"
