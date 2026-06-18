param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff.json")
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
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'pending', 'open')
$requiredFileKeys = @(
    'wave_files',
    'wave_files_zip',
    'wave_files_validation',
    'wave_signoff_csv',
    'wave_signoff',
    'wave_signoff_validation'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $waves = @($operatorPack.waves)
    $operatorFiles = @($operatorPack.operator_files)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 4) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 4 steps, found $($steps.Count)."
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

    $summaryItemCount = [int]$summary.signoff_items
    $statusTotal = [int]$summary.pending_items + [int]$summary.mitigated_items + [int]$summary.accepted_with_risk_items + [int]$summary.blocked_items
    if ($summaryItemCount -ne $waves.Count) {
        Add-Issue $issues 'blocker' 'summary.signoff_items' 'signoff_item_count_mismatch' "summary signoff_items ($summaryItemCount) does not match operator wave rows ($($waves.Count))."
    }
    if ($summaryItemCount -ne $statusTotal) {
        Add-Issue $issues 'blocker' 'summary.status_counts' 'status_count_mismatch' "summary status counts ($statusTotal) do not match signoff_items ($summaryItemCount)."
    }

    $readyStepCount = @($steps | Where-Object { $_.status -eq 'ready' }).Count
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' }).Count
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' "summary ready_steps does not match step statuses." }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' "summary pending_steps does not match step statuses." }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' "summary blocked_steps does not match step statuses." }

    $expectedValidationBlockers = [int]$summary.signoff_validation_blockers + [int]$summary.wave_package_validation_blockers
    $expectedValidationWarnings = [int]$summary.signoff_validation_warnings + [int]$summary.wave_package_validation_warnings
    if ([int]$summary.validation_blockers -ne $expectedValidationBlockers) {
        Add-Issue $issues 'blocker' 'summary.validation_blockers' 'validation_blocker_count_mismatch' 'summary validation_blockers does not equal signoff plus wave package validation blockers.'
    }
    if ([int]$summary.validation_warnings -ne $expectedValidationWarnings) {
        Add-Issue $issues 'blocker' 'summary.validation_warnings' 'validation_warning_count_mismatch' 'summary validation_warnings does not equal signoff plus wave package validation warnings.'
    }

    if ($signoff) {
        $signoffWaves = @($signoff.items | ForEach-Object { [string]$_.wave } | Sort-Object -Unique)
        $operatorWaves = @($waves | ForEach-Object { [string]$_.wave } | Sort-Object -Unique)
        $missingWaves = @($signoffWaves | Where-Object { $operatorWaves -notcontains $_ })
        $extraWaves = @($operatorWaves | Where-Object { $signoffWaves -notcontains $_ })
        foreach ($wave in $missingWaves) {
            Add-Issue $issues 'blocker' 'waves.wave' 'missing_signoff_wave' "operator pack is missing signoff wave: $wave."
        }
        foreach ($wave in $extraWaves) {
            Add-Issue $issues 'blocker' 'waves.wave' 'extra_operator_wave' "operator pack contains wave not present in signoff: $wave."
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the public executable remediation wave signoff operator pack. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_items = if ($operatorPack) { $operatorPack.summary.signoff_items } else { 0 }
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    signoff = $SignoffPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff operator pack validation written to $ReportPath"
