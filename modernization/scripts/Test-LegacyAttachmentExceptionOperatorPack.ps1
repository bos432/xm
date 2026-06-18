param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-operator-pack.json")
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
    'worksheet_csv',
    'patch_preview_csv',
    'template_csv'
)
$requiredArtifactKeys = @(
    'confirmation',
    'worksheet',
    'worksheet_import_preview',
    'template_patch_preview'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'attachment exception operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $artifacts = @($operatorPack.artifacts)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 4) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 4 steps, found $($steps.Count)."
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

    $operatorFileNames = @()
    if ($operatorPack.operator_files) {
        $operatorFileNames = @($operatorPack.operator_files.PSObject.Properties.Name)
        foreach ($name in $operatorFileNames) {
            $path = $operatorPack.operator_files.$name
            if (Test-Blank $path) {
                Add-Issue $issues 'blocker' 'operator_files.path' 'blank_operator_file_path' "operator file $name path is blank."
            } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                Add-Issue $issues 'blocker' 'operator_files.path' 'missing_operator_file' "operator file $name is missing: $path."
            }
        }
    }
    foreach ($key in $requiredFileKeys) {
        if ($operatorFileNames -notcontains $key) {
            Add-Issue $issues 'blocker' 'operator_files' 'missing_operator_file_key' "operator_files is missing required key: $key."
        }
    }

    $artifactKeys = @($artifacts | ForEach-Object { $_.key })
    foreach ($key in $requiredArtifactKeys) {
        if ($artifactKeys -notcontains $key) {
            Add-Issue $issues 'blocker' 'artifacts' 'missing_artifact_key' "artifacts is missing required key: $key."
        }
    }
    foreach ($artifact in $artifacts) {
        if (Test-Blank $artifact.key) { Add-Issue $issues 'warning' 'artifacts.key' 'blank_artifact_key' 'artifact key is blank.' }
        if (Test-Blank $artifact.path) {
            Add-Issue $issues 'blocker' 'artifacts.path' 'blank_artifact_path' "artifact $($artifact.key) path is blank."
        } elseif (-not (Test-Path -LiteralPath $artifact.path -PathType Leaf)) {
            Add-Issue $issues 'blocker' 'artifacts.path' 'missing_artifact_file' "artifact $($artifact.key) is missing: $($artifact.path)."
        }
        if ($artifact.exists -and $validStatuses -notcontains $artifact.status) {
            Add-Issue $issues 'blocker' 'artifacts.status' 'invalid_artifact_status' "artifact $($artifact.key) has invalid status: $($artifact.status)."
        }
    }

    $readyStepCount = @($steps | Where-Object { $_.status -eq 'ready' }).Count
    $pendingStepCount = @($steps | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' -or $_.status -eq 'open' }).Count
    $blockedStepCount = @($steps | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' }).Count
    if ([int]$summary.ready_steps -ne $readyStepCount) { Add-Issue $issues 'blocker' 'summary.ready_steps' 'ready_step_count_mismatch' 'summary ready_steps does not match step statuses.' }
    if ([int]$summary.pending_steps -ne $pendingStepCount) { Add-Issue $issues 'blocker' 'summary.pending_steps' 'pending_step_count_mismatch' 'summary pending_steps does not match step statuses.' }
    if ([int]$summary.blocked_steps -ne $blockedStepCount) { Add-Issue $issues 'blocker' 'summary.blocked_steps' 'blocked_step_count_mismatch' 'summary blocked_steps does not match step statuses.' }

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
    note = 'This report validates the attachment exception operator pack structure, required files, artifacts, and internal counts. It does not edit CSV files, copy files, import records, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        artifacts = if ($operatorPack) { @($operatorPack.artifacts).Count } else { 0 }
        operator_files = if ($operatorPack -and $operatorPack.operator_files) { @($operatorPack.operator_files.PSObject.Properties.Name).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy attachment exception operator pack validation written to $ReportPath"
