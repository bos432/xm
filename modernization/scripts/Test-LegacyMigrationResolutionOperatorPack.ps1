param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-operator-pack.json")
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
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'pending', 'open')
$requiredFileKeys = @(
    'resolution_worklist_csv',
    'resolution_row_worklist',
    'resolution_row_worklist_csv',
    'resolution_owner_row_worklists',
    'resolution_owner_template_row_worklists',
    'resolution_distribution_pack',
    'resolution_distribution_pack_zip',
    'resolution_distribution_signoff',
    'resolution_distribution_signoff_csv',
    'resolution_distribution_signoff_validation',
    'resolution_owner_worklists',
    'resolution_acceptance_gate',
    'resolution_acceptance_gate_csv',
    'unit_user_template',
    'project_template',
    'attachment_exception_template',
    'attachment_operator_pack'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'migration resolution operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $operatorFiles = @($operatorPack.operator_files)
    $templateProgress = @($operatorPack.template_progress)
    $acceptanceGates = @($operatorPack.acceptance_gates)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 13) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 13 steps, found $($steps.Count)."
    }

    foreach ($step in $steps) {
        if (Test-Blank $step.title) { Add-Issue $issues 'warning' 'steps.title' 'blank_step_title' "step $($step.order) title is blank." }
        if (Test-Blank $step.action) { Add-Issue $issues 'warning' 'steps.action' 'blank_step_action' "step $($step.order) action is blank." }
        if (Test-Blank $step.acceptance) { Add-Issue $issues 'warning' 'steps.acceptance' 'blank_step_acceptance' "step $($step.order) acceptance is blank." }
        if ($validStatuses -notcontains $step.status) {
            Add-Issue $issues 'blocker' 'steps.status' 'invalid_step_status' "step $($step.order) has invalid status: $($step.status)."
        }
        if (-not (Test-Blank $step.source) -and -not (Test-Path -LiteralPath $step.source -PathType Leaf)) {
            Add-Issue $issues 'blocker' 'steps.source' 'missing_step_source' "step $($step.order) source file is missing: $($step.source)."
        }
    }

    $fileKeys = @($operatorFiles | ForEach-Object { $_.key })
    foreach ($key in $requiredFileKeys) {
        if ($fileKeys -notcontains $key) {
            Add-Issue $issues 'blocker' 'operator_files' 'missing_operator_file_key' "operator_files is missing required key: $key."
        }
    }

    foreach ($file in $operatorFiles) {
        if (Test-Blank $file.key) { Add-Issue $issues 'warning' 'operator_files.key' 'blank_operator_file_key' 'operator file key is blank.' }
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

    $templateTotalRows = 0
    $templateReadyRows = 0
    $templatePendingRows = 0
    $templateBlockedRows = 0
    foreach ($template in $templateProgress) {
        if (Test-Blank $template.template) { Add-Issue $issues 'warning' 'template_progress.template' 'blank_template_name' 'template progress row has a blank template name.' }
        $templateTotalRows += [int]$template.total_rows
        $templateReadyRows += [int]$template.ready_rows
        $templatePendingRows += [int]$template.pending_rows
        $templateBlockedRows += [int]$template.blocked_rows
    }
    if ([int]$summary.total_rows -ne $templateTotalRows) { Add-Issue $issues 'blocker' 'summary.total_rows' 'total_rows_mismatch' 'summary total_rows does not match template progress totals.' }
    if ([int]$summary.ready_rows -ne $templateReadyRows) { Add-Issue $issues 'blocker' 'summary.ready_rows' 'ready_rows_mismatch' 'summary ready_rows does not match template progress totals.' }
    if ([int]$summary.pending_rows -ne $templatePendingRows) { Add-Issue $issues 'blocker' 'summary.pending_rows' 'pending_rows_mismatch' 'summary pending_rows does not match template progress totals.' }
    if ([int]$summary.blocked_rows -ne $templateBlockedRows) { Add-Issue $issues 'blocker' 'summary.blocked_rows' 'blocked_rows_mismatch' 'summary blocked_rows does not match template progress totals.' }

    if ($operatorPack.row_worklist_by_owner) {
        $ownerRows = 0
        $ownerP1Rows = 0
        foreach ($owner in @($operatorPack.row_worklist_by_owner)) {
            $ownerRows += [int]$owner.rows
            $ownerP1Rows += [int]$owner.p1_rows
        }
        if ($operatorPack.row_worklist_summary -and [int]$operatorPack.row_worklist_summary.row_work_items -ne $ownerRows) {
            Add-Issue $issues 'blocker' 'row_worklist_summary.row_work_items' 'row_worklist_owner_count_mismatch' 'row worklist summary row count does not match owner totals.'
        }
        if ($operatorPack.row_worklist_summary -and [int]$operatorPack.row_worklist_summary.p1_rows -ne $ownerP1Rows) {
            Add-Issue $issues 'blocker' 'row_worklist_summary.p1_rows' 'row_worklist_owner_p1_mismatch' 'row worklist summary P1 count does not match owner totals.'
        }
    }

    if ([int]$summary.acceptance_total_gates -ne $acceptanceGates.Count) {
        Add-Issue $issues 'blocker' 'summary.acceptance_total_gates' 'acceptance_gate_count_mismatch' 'summary acceptance_total_gates does not match acceptance_gates rows.'
    }
    $passedGates = @($acceptanceGates | Where-Object { $_.status -eq 'pass' }).Count
    $openGates = @($acceptanceGates | Where-Object { $_.status -ne 'pass' }).Count
    if ([int]$summary.acceptance_passed_gates -ne $passedGates) { Add-Issue $issues 'blocker' 'summary.acceptance_passed_gates' 'passed_gate_count_mismatch' 'summary acceptance_passed_gates does not match gate statuses.' }
    if ([int]$summary.acceptance_open_gates -ne $openGates) { Add-Issue $issues 'blocker' 'summary.acceptance_open_gates' 'open_gate_count_mismatch' 'summary acceptance_open_gates does not match gate statuses.' }

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
    note = 'This report validates the migration resolution operator pack structure, required files, and internal counts. It does not edit CSV files, copy files, update resolved maps, import records, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        template_progress = if ($operatorPack) { @($operatorPack.template_progress).Count } else { 0 }
        acceptance_gates = if ($operatorPack) { @($operatorPack.acceptance_gates).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution operator pack validation written to $ReportPath"
