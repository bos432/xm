param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff.json")
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
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'open', 'pending', 'archive', 'link', 'exclude')
$requiredFileKeys = @(
    'workflow_orphan_signoff_csv',
    'workflow_orphan_signoff',
    'workflow_orphan_validation',
    'workflow_dry_run'
)

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'workflow orphan operator pack report is missing.'
} else {
    $steps = @($operatorPack.steps)
    $operatorFiles = @($operatorPack.operator_files)
    $projects = @($operatorPack.by_legacy_project)
    $pendingItems = @($operatorPack.pending_items)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($steps.Count -ne 3) {
        Add-Issue $issues 'blocker' 'steps' 'step_count_mismatch' "operator pack should contain 3 steps, found $($steps.Count)."
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
    if ([int]$summary.legacy_project_count -ne $projects.Count) { Add-Issue $issues 'blocker' 'summary.legacy_project_count' 'legacy_project_count_mismatch' 'summary legacy_project_count does not match by_legacy_project rows.' }

    $projectOrphanCount = 0
    $projectPendingCount = 0
    $projectArchiveCount = 0
    $projectLinkCount = 0
    $projectExcludeCount = 0
    $projectBlockedCount = 0
    foreach ($project in $projects) {
        if (Test-Blank $project.legacy_project_id) { Add-Issue $issues 'warning' 'by_legacy_project.legacy_project_id' 'blank_legacy_project_id' 'legacy project id is blank.' }
        $projectOrphanCount += [int]$project.orphan_rows
        $projectPendingCount += [int]$project.pending_items
        $projectArchiveCount += [int]$project.archive_items
        $projectLinkCount += [int]$project.link_items
        $projectExcludeCount += [int]$project.exclude_items
        $projectBlockedCount += [int]$project.blocked_items
    }

    if ([int]$summary.orphan_items -ne $projectOrphanCount) { Add-Issue $issues 'blocker' 'summary.orphan_items' 'orphan_item_count_mismatch' 'summary orphan_items does not match project totals.' }
    if ([int]$summary.pending_items -ne $projectPendingCount) { Add-Issue $issues 'blocker' 'summary.pending_items' 'pending_item_count_mismatch' 'summary pending_items does not match project totals.' }
    if ([int]$summary.archive_items -ne $projectArchiveCount) { Add-Issue $issues 'blocker' 'summary.archive_items' 'archive_item_count_mismatch' 'summary archive_items does not match project totals.' }
    if ([int]$summary.link_items -ne $projectLinkCount) { Add-Issue $issues 'blocker' 'summary.link_items' 'link_item_count_mismatch' 'summary link_items does not match project totals.' }
    if ([int]$summary.exclude_items -ne $projectExcludeCount) { Add-Issue $issues 'blocker' 'summary.exclude_items' 'exclude_item_count_mismatch' 'summary exclude_items does not match project totals.' }
    if ([int]$summary.blocked_items -ne $projectBlockedCount) { Add-Issue $issues 'blocker' 'summary.blocked_items' 'blocked_item_count_mismatch' 'summary blocked_items does not match project totals.' }
    if ([int]$summary.decided_items -ne ([int]$summary.archive_items + [int]$summary.link_items + [int]$summary.exclude_items)) {
        Add-Issue $issues 'blocker' 'summary.decided_items' 'decided_item_count_mismatch' 'summary decided_items does not match archive/link/exclude totals.'
    }

    $sourceOrphanItems = if ($signoff -and $signoff.summary.PSObject.Properties.Name -contains 'orphan_items') { [int]$signoff.summary.orphan_items } elseif ($signoff -and $signoff.summary.PSObject.Properties.Name -contains 'orphan_rows') { [int]$signoff.summary.orphan_rows } else { $null }
    if ($null -ne $sourceOrphanItems -and $sourceOrphanItems -ne [int]$summary.orphan_items) {
        Add-Issue $issues 'blocker' 'summary.orphan_items' 'source_signoff_count_mismatch' 'operator orphan count does not match source signoff orphan row count.'
    }

    if ($pendingItems.Count -gt [int]$summary.pending_items) {
        Add-Issue $issues 'blocker' 'pending_items' 'pending_orphan_overflow' 'operator pack pending_items contains more rows than summary pending_items.'
    }

    $expectedStatus = if ($blockedStepCount -gt 0 -or [int]$summary.blocked_items -gt 0 -or [int]$summary.invalid_items -gt 0 -or [int]$summary.validation_blockers -gt 0) { 'blocked' } elseif ($pendingStepCount -gt 0 -or [int]$summary.pending_items -gt 0 -or [int]$summary.validation_warnings -gt 0) { 'not_ready' } else { 'ready' }
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
    note = 'This report validates the workflow orphan operator pack structure, required files, and internal counts. It does not import records, link records, archive records, exclude records, update CSV files, or write database records.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        steps = if ($operatorPack) { @($operatorPack.steps).Count } else { 0 }
        legacy_projects = if ($operatorPack) { @($operatorPack.by_legacy_project).Count } else { 0 }
        operator_files = if ($operatorPack) { @($operatorPack.operator_files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy workflow orphan operator pack validation written to $ReportPath"
