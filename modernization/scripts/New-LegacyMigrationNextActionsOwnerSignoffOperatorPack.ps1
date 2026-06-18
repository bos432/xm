param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff-operator-pack.json"),
    [string]$OwnerFilesPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.json"),
    [string]$OwnerFilesValidationPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files-validation.json"),
    [string]$SignoffPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff.json"),
    [string]$SignoffValidationPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff-validation.json")
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

$ownerFiles = Read-JsonReport $OwnerFilesPath
$ownerFilesValidation = Read-JsonReport $OwnerFilesValidationPath
$signoff = Read-JsonReport $SignoffPath
$signoffValidation = Read-JsonReport $SignoffValidationPath

$steps = New-Object System.Collections.Generic.List[object]

$ownerFilesStatus = if ($ownerFilesValidation) { $ownerFilesValidation.overall_status } elseif ($ownerFiles) { 'not_ready' } else { 'missing' }
Add-Step $steps 1 'Prepare owner next-action handoff files' $ownerFilesStatus 'Generate owner-specific CSV/Markdown files and the owner ZIP package.' 'Owner file validation is ready and the ZIP contains every expected entry.' $OwnerFilesValidationPath

$signoffStatus = if ($signoff) { $signoff.overall_status } else { 'missing' }
Add-Step $steps 2 'Collect owner next-action handoff signoff' $signoffStatus 'Send each owner package and update legacy-migration-next-actions.owner-signoff.csv.' 'Every owner handoff row is completed.' $SignoffPath

$validationStatus = if ($signoffValidation) { $signoffValidation.overall_status } else { 'missing' }
Add-Step $steps 3 'Validate owner handoff signoff fields' $validationStatus 'Fix missing recipient, sent_at, evidence_ref, accepted_by, accepted_at, completed_by, and completed_at fields.' 'Owner signoff validation has zero blockers and zero warnings.' $SignoffValidationPath

$items = if ($signoff -and $signoff.items) { @($signoff.items) } else { @() }
$issues = if ($signoffValidation -and $signoffValidation.issues) { @($signoffValidation.issues) } else { @() }

$owners = @()
foreach ($item in @($items)) {
    $owners += [ordered]@{
        owner = $item.owner
        slug = $item.slug
        status = $item.status
        recipient = $item.recipient
        action_count = $item.action_count
        blockers = $item.blockers
        warnings = $item.warnings
        csv_path = $item.csv_path
        markdown_path = $item.markdown_path
        blocker_csv_path = $item.blocker_csv_path
        blocker_markdown_path = $item.blocker_markdown_path
        sent_at = $item.sent_at
        accepted_by = $item.accepted_by
        accepted_at = $item.accepted_at
        completed_by = $item.completed_by
        completed_at = $item.completed_at
        evidence_ref = $item.evidence_ref
        notes = $item.notes
    }
}

$pendingItems = @($items | Where-Object { $_.status -eq 'pending' }).Count
$sentItems = @($items | Where-Object { $_.status -eq 'sent' }).Count
$acceptedItems = @($items | Where-Object { $_.status -eq 'accepted' }).Count
$completedItems = @($items | Where-Object { $_.status -eq 'completed' }).Count
$blockedItems = @($items | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = if ($signoff) { $signoff.summary.invalid_items } else { 0 }
$ownerFileValidationBlockers = if ($ownerFilesValidation) { $ownerFilesValidation.summary.blockers } else { 0 }
$ownerFileValidationWarnings = if ($ownerFilesValidation) { $ownerFilesValidation.summary.warnings } else { 0 }
$validationBlockers = @($issues | Where-Object { $_.severity -eq 'blocker' }).Count
$validationWarnings = @($issues | Where-Object { $_.severity -eq 'warning' }).Count

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'missing' -or $_.status -eq 'blocked' })
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
    note = 'This operator pack summarizes owner-specific next-action handoff signoff. It does not send files, copy legacy attachments, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0 -or $blockedItems -gt 0 -or $invalidItems -gt 0 -or $ownerFileValidationBlockers -gt 0 -or $validationBlockers -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0 -or $pendingItems -gt 0 -or $sentItems -gt 0 -or $acceptedItems -gt 0 -or $ownerFileValidationWarnings -gt 0 -or $validationWarnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        owner_items = $items.Count
        pending_items = $pendingItems
        sent_items = $sentItems
        accepted_items = $acceptedItems
        completed_items = $completedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        owner_file_validation_blockers = $ownerFileValidationBlockers
        owner_file_validation_warnings = $ownerFileValidationWarnings
        signoff_validation_blockers = $validationBlockers
        signoff_validation_warnings = $validationWarnings
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = @(
        New-FileEntry 'next_actions' (Join-Path $PSScriptRoot 'legacy-migration-next-actions.json') 'prioritized next actions report'
        New-FileEntry 'owner_files_manifest' $OwnerFilesPath 'manifest of owner-specific next-action files'
        New-FileEntry 'owner_files_zip' (Join-Path $PSScriptRoot 'legacy-migration-next-actions.owner-files.zip') 'ZIP package of owner-specific next-action files'
        New-FileEntry 'owner_files_validation' $OwnerFilesValidationPath 'validation report for owner files and ZIP contents'
        New-FileEntry 'owner_signoff_csv' (Join-Path $PSScriptRoot 'legacy-migration-next-actions.owner-signoff.csv') 'manual owner handoff signoff CSV'
        New-FileEntry 'owner_signoff' $SignoffPath 'JSON summary of owner handoff signoff statuses'
        New-FileEntry 'owner_signoff_validation' $SignoffValidationPath 'validation report for owner handoff signoff fields'
    )
    owners = @($owners)
    validation_issues = @($issues | Select-Object -First 50)
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions owner signoff operator pack written to $ReportPath"
