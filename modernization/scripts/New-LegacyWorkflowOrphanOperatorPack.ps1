param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-operator-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff.json"),
    [string]$ValidationPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff-validation.json"),
    [string]$WorkflowDryRunPath = (Join-Path $PSScriptRoot "legacy-workflow-db-dry-run.json")
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
$workflowDryRun = Read-JsonReport $WorkflowDryRunPath

$steps = New-Object System.Collections.Generic.List[object]

$dryRunStatus = if ($workflowDryRun) { 'ready' } else { 'missing' }
Add-Step $steps 1 'Generate workflow row-level dry-run' $dryRunStatus 'Run New-LegacyWorkflowDbDryRun.ps1 to identify orphan project references.' 'Workflow dry-run exists and contains orphan reference counts.' $WorkflowDryRunPath

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 2 'Complete orphan workflow handling decisions' $signoffStatus 'Choose archive, link, or exclude for each orphan workflow row in the signoff CSV.' 'All orphan rows have approved handling decisions.' $SignoffPath

$validationStatus = if ($validation) { $validation.overall_status } else { 'missing' }
Add-Step $steps 3 'Validate orphan workflow decision fields' $validationStatus 'Fix invalid decisions, missing target links, or missing approval evidence.' 'Validation has zero blockers and zero warnings.' $ValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$pendingItems = @($items | Where-Object { $_.decision -eq 'pending' })
$blockedItems = @($items | Where-Object { $_.decision -eq 'blocked' })
$invalidItems = @($items | Where-Object { $_.decision -notin @('pending', 'archive', 'link', 'exclude', 'blocked') })
$decidedItems = @($items | Where-Object { $_.decision -in @('archive', 'link', 'exclude') })

$byLegacyProject = @()
foreach ($group in @($items | Group-Object legacy_project_id | Sort-Object Name)) {
    $groupItems = @($group.Group)
    $byLegacyProject += [ordered]@{
        legacy_project_id = $group.Name
        orphan_rows = $groupItems.Count
        pending_items = @($groupItems | Where-Object { $_.decision -eq 'pending' }).Count
        archive_items = @($groupItems | Where-Object { $_.decision -eq 'archive' }).Count
        link_items = @($groupItems | Where-Object { $_.decision -eq 'link' }).Count
        exclude_items = @($groupItems | Where-Object { $_.decision -eq 'exclude' }).Count
        blocked_items = @($groupItems | Where-Object { $_.decision -eq 'blocked' }).Count
        sample_legacy_ids = @($groupItems | Select-Object -First 5 -ExpandProperty legacy_id)
        stages = @($groupItems | ForEach-Object { $_.stage } | Where-Object { $_ } | Sort-Object -Unique)
    }
}

$issues = if ($validation -and $validation.issues) { @($validation.issues) } else { @() }
$blockers = @($issues | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues | Where-Object { $_.severity -eq 'warning' }).Count

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'blocked' -or $_.status -eq 'missing' })
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
    note = 'This operator pack summarizes orphan workflow handling decisions. It does not import records, link records, archive records, exclude records, update CSV files, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $blockers -gt 0 -or $invalidItems.Count -gt 0 -or $blockedItems.Count -gt 0) { 'blocked' } elseif ($pendingItems.Count -gt 0 -or $warnings -gt 0 -or $pendingSteps.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        orphan_items = $items.Count
        legacy_project_count = @($byLegacyProject).Count
        pending_items = $pendingItems.Count
        decided_items = $decidedItems.Count
        archive_items = @($items | Where-Object { $_.decision -eq 'archive' }).Count
        link_items = @($items | Where-Object { $_.decision -eq 'link' }).Count
        exclude_items = @($items | Where-Object { $_.decision -eq 'exclude' }).Count
        blocked_items = $blockedItems.Count
        invalid_items = $invalidItems.Count
        validation_blockers = $blockers
        validation_warnings = $warnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'workflow_orphan_signoff_csv' (Join-Path $PSScriptRoot 'legacy-workflow-orphan-resolution-signoff.csv') 'business-fillable decision sheet for orphan workflow rows'
        New-FileEntry 'workflow_orphan_signoff' $SignoffPath 'JSON summary of orphan workflow handling decisions'
        New-FileEntry 'workflow_orphan_validation' $ValidationPath 'validation report for manual decision fields'
        New-FileEntry 'workflow_dry_run' $WorkflowDryRunPath 'source row-level workflow dry-run report'
    )
    by_legacy_project = @($byLegacyProject)
    pending_items = @($pendingItems | Select-Object -First 50)
    validation_issues = @($issues | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy workflow orphan operator pack written to $ReportPath"
