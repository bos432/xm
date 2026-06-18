param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-blocker-operator-pack.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-blocker-operator-pack.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-blocker-operator-pack.md")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Value($value, $fallback = '-') {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $fallback }
    return [string]$value
}

function Get-Owner($category) {
    switch ($category) {
        'batch' { return 'data_migration_owner' }
        'security_baseline_operator_pack' { return 'security_owner' }
        'security_baseline_signoff' { return 'security_owner' }
        'security_baseline_signoff_validation' { return 'security_owner' }
        'go_live_drill_operator_pack' { return 'technical_owner' }
        'blocker_resolution_operator_pack' { return 'operations_owner' }
        'go_live_signoff_operator_pack' { return 'technical_owner' }
        default { return 'technical_owner' }
    }
}

function Get-Acceptance($item) {
    switch ($item.category) {
        'batch' {
            if ($item.source -eq 'attachment_copy') { return 'Attachment copy stage is verified through dry-run evidence and any real copy remains gated by explicit Execute approval.' }
            if ($item.source -eq 'project_files') { return 'Project file rows have valid project mappings and no unresolved blocked records.' }
            return 'Batch stage no longer appears as blocker in preflight.'
        }
        'security_baseline_operator_pack' { return 'Security baseline operator pack has zero blocked steps; public executable exposure and infected leftovers are mitigated or accepted with documented risk.' }
        'security_baseline_signoff' { return 'Every security baseline signoff row is mitigated or accepted_with_risk.' }
        'security_baseline_signoff_validation' { return 'Security baseline signoff validation has zero blockers and zero warnings.' }
        'go_live_drill_operator_pack' { return 'Go-live drill operator pack has zero blocked steps after preflight blockers are resolved.' }
        default { return 'Item is no longer emitted as blocker or warning in preflight.' }
    }
}

function Format-MarkdownText($value) {
    return (Get-Value $value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function New-FileEntry($key, $path, $purpose, $required = $true) {
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [ordered]@{
        key = $key
        path = $path
        file_name = [System.IO.Path]::GetFileName($path)
        purpose = $purpose
        required = [bool]$required
        exists = $exists
        updated_at = if ($exists) { (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') } else { $null }
    }
}

$preflightPath = Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json'
$securityPackPath = Join-Path $ScriptsRoot 'legacy-security-baseline-operator-pack.json'
$securitySignoffPath = Join-Path $ScriptsRoot 'legacy-security-baseline-signoff.json'
$securityValidationPath = Join-Path $ScriptsRoot 'legacy-security-baseline-signoff-validation.json'
$blockerOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-blocker-resolution-operator-pack.json'
$drillOperatorPath = Join-Path $ScriptsRoot 'legacy-migration-go-live-drill-operator-pack.json'
$nextActionsPath = Join-Path $ScriptsRoot 'legacy-migration-next-actions.json'

$preflight = Read-JsonReport $preflightPath
$securityPack = Read-JsonReport $securityPackPath
$securitySignoff = Read-JsonReport $securitySignoffPath
$securityValidation = Read-JsonReport $securityValidationPath
$blockerOperator = Read-JsonReport $blockerOperatorPath
$drillOperator = Read-JsonReport $drillOperatorPath
$nextActions = Read-JsonReport $nextActionsPath

$items = if ($preflight -and $preflight.items) { @($preflight.items | Where-Object { $_.severity -eq 'blocker' -or $_.severity -eq 'warning' }) } else { @() }
$actions = New-Object System.Collections.Generic.List[object]
$order = 0

foreach ($item in @($items)) {
    $order++
    $severityRank = if ($item.severity -eq 'blocker') { 1 } elseif ($item.severity -eq 'warning') { 2 } else { 3 }
    $actions.Add([pscustomobject][ordered]@{
        order = $order
        priority = $severityRank
        category = $item.category
        severity = $item.severity
        status = $item.status
        title = $item.title
        owner = Get-Owner $item.category
        source = $item.source
        evidence = $item.action
        action = $item.action
        acceptance = Get-Acceptance $item
    })
}

$sortedActions = @($actions.ToArray() | Sort-Object priority, category, title)
$blockers = @($sortedActions | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($sortedActions | Where-Object { $_.severity -eq 'warning' }).Count
$ownerGroups = @($sortedActions | Group-Object owner | ForEach-Object {
    [ordered]@{
        owner = $_.Name
        total_actions = $_.Count
        blockers = @($_.Group | Where-Object { $_.severity -eq 'blocker' }).Count
        warnings = @($_.Group | Where-Object { $_.severity -eq 'warning' }).Count
        categories = @($_.Group | Select-Object -ExpandProperty category -Unique)
    }
})
$topActions = @($sortedActions | Select-Object -First 15)
$nextAction = $sortedActions | Select-Object -First 1

@($sortedActions) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Legacy Migration Preflight Blocker Operator Pack')
$lines.Add('')
$lines.Add('Generated at: ' + (Get-Date -Format o))
$lines.Add('')
$lines.Add('This operator pack summarizes preflight blockers and warnings. It does not copy files, import records, switch traffic, update templates, delete files, quarantine files, or change web server config.')
$lines.Add('')
$lines.Add('## Summary')
$lines.Add('')
$lines.Add('- Overall status: ' + $(if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }))
$lines.Add('- Blockers: ' + $blockers)
$lines.Add('- Warnings: ' + $warnings)
$lines.Add('- Owners: ' + $ownerGroups.Count)
$lines.Add('')
$lines.Add('## Top Actions')
$lines.Add('')
$lines.Add('| Priority | Severity | Owner | Category | Status | Title | Action | Acceptance |')
$lines.Add('| ---: | --- | --- | --- | --- | --- | --- | --- |')
foreach ($item in $topActions) {
    $lines.Add("| $($item.priority) | $(Format-MarkdownText $item.severity) | $(Format-MarkdownText $item.owner) | $(Format-MarkdownText $item.category) | $(Format-MarkdownText $item.status) | $(Format-MarkdownText $item.title) | $(Format-MarkdownText $item.action) | $(Format-MarkdownText $item.acceptance) |")
}
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This operator pack summarizes preflight blockers and warnings. It does not copy files, import records, switch traffic, update templates, delete files, quarantine files, or change web server config.'
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_actions = $sortedActions.Count
        blockers = $blockers
        warnings = $warnings
        owner_count = $ownerGroups.Count
        preflight_status = if ($preflight) { $preflight.overall_status } else { 'missing' }
        security_status = if ($securityPack) { $securityPack.overall_status } else { 'missing' }
        security_signoff_status = if ($securitySignoff) { $securitySignoff.overall_status } else { 'missing' }
        security_signoff_warnings = if ($securityValidation) { $securityValidation.summary.warnings } else { 0 }
        blocker_operator_status = if ($blockerOperator) { $blockerOperator.overall_status } else { 'missing' }
        drill_operator_status = if ($drillOperator) { $drillOperator.overall_status } else { 'missing' }
        next_actions_status = if ($nextActions) { $nextActions.overall_status } else { 'missing' }
    }
    next_action = $nextAction
    owners = @($ownerGroups)
    top_actions = @($topActions)
    actions = @($sortedActions)
    files = @(
        New-FileEntry 'preflight_checklist' $preflightPath 'preflight blockers and warnings'
        New-FileEntry 'security_baseline_operator_pack' $securityPackPath 'security baseline operator pack'
        New-FileEntry 'security_baseline_signoff' $securitySignoffPath 'security baseline signoff'
        New-FileEntry 'security_baseline_signoff_validation' $securityValidationPath 'security baseline signoff validation'
        New-FileEntry 'blocker_resolution_operator_pack' $blockerOperatorPath 'blocked stage resolution operator pack'
        New-FileEntry 'go_live_drill_operator_pack' $drillOperatorPath 'go-live drill operator pack'
        New-FileEntry 'next_actions' $nextActionsPath 'prioritized next actions report'
        New-FileEntry 'preflight_blocker_operator_pack_csv' $CsvPath 'CSV version of this operator pack'
        New-FileEntry 'preflight_blocker_operator_pack_md' $MarkdownPath 'Markdown version of this operator pack'
    )
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration preflight blocker operator pack written to $ReportPath"
Write-Host "Legacy migration preflight blocker operator pack CSV written to $CsvPath"
Write-Host "Legacy migration preflight blocker operator pack Markdown written to $MarkdownPath"