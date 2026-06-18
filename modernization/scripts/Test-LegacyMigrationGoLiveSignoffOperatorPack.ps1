param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff.json")
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
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'open', 'pending', 'signed', 'accepted_with_risk', 'rejected')
$requiredFileKeys = @(
    'go_live_signoff_csv',
    'go_live_signoff',
    'go_live_signoff_validation',
    'go_live_gate',
    'evidence_pack'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'go-live signoff operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $roles = @($operatorPack.roles)
    $operatorFiles = @($operatorPack.operator_files)
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

    foreach ($role in $roles) {
        if (Test-Blank $role.role_key) { Add-Issue $issues 'warning' 'roles.role_key' 'blank_role_key' 'role key is blank.' }
        if (Test-Blank $role.role_name) { Add-Issue $issues 'warning' 'roles.role_name' 'blank_role_name' "role $($role.role_key) name is blank." }
        if ($validStatuses -notcontains $role.status) {
            Add-Issue $issues 'blocker' 'roles.status' 'invalid_role_status' "role $($role.role_key) has invalid status: $($role.status)."
        }
    }

    $pendingItems = @($roles | Where-Object { $_.status -eq 'pending' }).Count
    $signedItems = @($roles | Where-Object { $_.status -eq 'signed' }).Count
    $riskItems = @($roles | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
    $rejectedItems = @($roles | Where-Object { $_.status -eq 'rejected' }).Count
    if ([int]$summary.signoff_items -ne $roles.Count) { Add-Issue $issues 'blocker' 'summary.signoff_items' 'signoff_item_count_mismatch' 'summary signoff_items does not match role rows.' }
    if ([int]$summary.pending_items -ne $pendingItems) { Add-Issue $issues 'blocker' 'summary.pending_items' 'pending_item_count_mismatch' 'summary pending_items does not match role statuses.' }
    if ([int]$summary.signed_items -ne $signedItems) { Add-Issue $issues 'blocker' 'summary.signed_items' 'signed_item_count_mismatch' 'summary signed_items does not match role statuses.' }
    if ([int]$summary.accepted_with_risk_items -ne $riskItems) { Add-Issue $issues 'blocker' 'summary.accepted_with_risk_items' 'risk_item_count_mismatch' 'summary accepted_with_risk_items does not match role statuses.' }
    if ([int]$summary.rejected_items -ne $rejectedItems) { Add-Issue $issues 'blocker' 'summary.rejected_items' 'rejected_item_count_mismatch' 'summary rejected_items does not match role statuses.' }

    $readyStepCount = @($steps | Where-Object { $_.status -eq 'ready' }).Count
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' }).Count
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' 'summary ready_steps does not match step statuses.' }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' 'summary pending_steps does not match step statuses.' }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' 'summary blocked_steps does not match step statuses.' }

    if ($signoff -and [int]$signoff.summary.signoff_items -ne $roles.Count) {
        Add-Issue $issues 'blocker' 'roles' 'source_signoff_count_mismatch' 'operator role count does not match source signoff item count.'
    }

    $expectedStatus = if ($blockedStepCount -gt 0 -or $rejectedItems -gt 0 -or [int]$summary.invalid_items -gt 0 -or [int]$summary.validation_blockers -gt 0) { 'blocked' } elseif ($pendingStepCount -gt 0 -or $pendingItems -gt 0 -or [int]$summary.validation_warnings -gt 0) { 'not_ready' } else { 'ready' }
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
    note = 'This report validates the final go-live signoff operator pack structure and internal counts. It does not sign roles, copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        roles = if ($operatorPack) { @($operatorPack.roles).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live signoff operator pack validation written to $ReportPath"
