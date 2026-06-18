param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-operator-pack.json"),
    [string]$ResolutionPackPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff.json"),
    [string]$ValidationPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff-validation.json")
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

$resolutionPack = Read-JsonReport $ResolutionPackPath
$signoff = Read-JsonReport $SignoffPath
$validation = Read-JsonReport $ValidationPath

$steps = New-Object System.Collections.Generic.List[object]

$packStatus = if ($resolutionPack) { $resolutionPack.overall_status } else { 'missing' }
Add-Step $steps 1 'Review blocker resolution plan' $packStatus 'Review allowed actions, forbidden actions, manual commands, and validation checks for each blocked stage.' 'Every blocked stage has an owner and documented resolution path.' $ResolutionPackPath

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 2 'Approve, execute, and verify blocked stages' $signoffStatus 'Use legacy-migration-blocker-resolution-signoff.csv to track approval, execution, and verification.' 'Every signoff row is verified.' $SignoffPath

$validationStatus = if ($validation) { $validation.overall_status } else { 'missing' }
Add-Step $steps 3 'Validate blocker signoff fields' $validationStatus 'Fix invalid statuses or missing approval, execution, verification, and notes fields.' 'Validation has zero blockers and zero warnings.' $ValidationPath

$packItems = if ($resolutionPack -and $resolutionPack.items) { @($resolutionPack.items) } else { @() }
$signoffItems = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$validationIssues = if ($validation -and $validation.issues) { @($validation.issues) } else { @() }

$signoffByStage = @{}
foreach ($row in @($signoffItems)) {
    $stage = ([string]$row.stage).Trim().ToLowerInvariant()
    if ($stage) { $signoffByStage[$stage] = $row }
}

$stageItems = @()
foreach ($item in @($packItems)) {
    $stage = ([string]$item.stage).Trim().ToLowerInvariant()
    $signoffRow = if ($signoffByStage.ContainsKey($stage)) { $signoffByStage[$stage] } else { $null }
    $stageItems += [ordered]@{
        stage = $item.stage
        status = $item.status
        signoff_status = if ($signoffRow) { $signoffRow.status } else { 'missing' }
        owner = $item.owner
        blocked_count = $item.blocked_count
        waiting_count = $item.waiting_count
        warnings = @($item.warnings)
        evidence_reports = @($item.evidence_reports)
        allowed_actions = @($item.allowed_actions)
        forbidden_actions = @($item.forbidden_actions)
        validation_checks = @($item.validation_checks)
        manual_commands = @($item.manual_commands)
        approved_by = if ($signoffRow) { $signoffRow.approved_by } else { '' }
        executed_by = if ($signoffRow) { $signoffRow.executed_by } else { '' }
        verified_by = if ($signoffRow) { $signoffRow.verified_by } else { '' }
        notes = if ($signoffRow) { $signoffRow.notes } else { '' }
    }
}

$pendingSignoff = @($signoffItems | Where-Object { $_.status -eq 'pending' }).Count
$approvedSignoff = @($signoffItems | Where-Object { $_.status -eq 'approved' }).Count
$executedSignoff = @($signoffItems | Where-Object { $_.status -eq 'executed' }).Count
$verifiedSignoff = @($signoffItems | Where-Object { $_.status -eq 'verified' }).Count
$blockedSignoff = @($signoffItems | Where-Object { $_.status -eq 'blocked' }).Count
$invalidSignoff = if ($signoff) { $signoff.summary.invalid_items } else { 0 }
$validationBlockers = @($validationIssues | Where-Object { $_.severity -eq 'blocker' }).Count
$validationWarnings = @($validationIssues | Where-Object { $_.severity -eq 'warning' }).Count

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'open' -or $_.status -eq 'pending' })
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
    note = 'This operator pack summarizes blocker resolution approval, execution, and verification. It does not copy files, import records, update templates, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $blockedSignoff -gt 0 -or $invalidSignoff -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingSignoff -gt 0 -or $approvedSignoff -gt 0 -or $executedSignoff -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        blocked_stages = if ($resolutionPack) { $resolutionPack.summary.blocked_stages } else { 0 }
        signoff_items = if ($signoff) { $signoff.summary.signoff_items } else { 0 }
        pending_items = $pendingSignoff
        approved_items = $approvedSignoff
        executed_items = $executedSignoff
        verified_items = $verifiedSignoff
        blocked_items = $blockedSignoff
        invalid_items = $invalidSignoff
        validation_blockers = $validationBlockers
        validation_warnings = $validationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'blocker_resolution_pack' $ResolutionPackPath 'resolution plan with allowed actions, forbidden actions, and validation checks'
        New-FileEntry 'blocker_resolution_pack_csv' (Join-Path $PSScriptRoot 'legacy-migration-blocker-resolution-pack.csv') 'CSV version of blocked stage resolution plan'
        New-FileEntry 'blocker_resolution_pack_md' (Join-Path $PSScriptRoot 'legacy-migration-blocker-resolution-pack.md') 'Markdown version of blocked stage resolution plan'
        New-FileEntry 'blocker_resolution_signoff_csv' (Join-Path $PSScriptRoot 'legacy-migration-blocker-resolution-signoff.csv') 'manual approval, execution, and verification signoff sheet'
        New-FileEntry 'blocker_resolution_signoff' $SignoffPath 'JSON summary of blocker resolution signoff'
        New-FileEntry 'blocker_resolution_signoff_validation' $ValidationPath 'validation report for manual signoff fields'
    )
    stages = @($stageItems)
    validation_issues = @($validationIssues | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker resolution operator pack written to $ReportPath"
