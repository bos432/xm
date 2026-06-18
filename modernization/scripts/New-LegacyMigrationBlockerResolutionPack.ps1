param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.md")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Number($value) {
    if ($null -eq $value) { return 0 }
    return [int64]$value
}

function Join-Values($values) {
    $items = @($values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return '-' }
    return ($items -join '; ')
}

function Find-ActionItems($actionSheet, $keys) {
    if (-not $actionSheet) { return @() }
    return @($actionSheet.items | Where-Object { $keys -contains $_.key })
}

function Get-AllowedActions($stageKey) {
    if ($stageKey -eq 'attachment_copy') {
        return @(
            'Review attachment dry-run blocked rows and missing attachment exception worksheet.',
            'Recover source files from backup or approve documented attachment exceptions.',
            'Run Invoke-LegacyAttachmentImportDryRun.ps1 -Execute only after dry-run approval and migration-window signoff.'
        )
    }
    if ($stageKey -eq 'project_files') {
        return @(
            'Complete production project id mappings in legacy-project-id-map.template.csv.',
            'Regenerate resolved mapping reports and project file DB dry-run.',
            'Import project file records only after project mapping and attachment copy evidence are ready.'
        )
    }
    return @('Review the source report and update the matching migration template before production execution.')
}

function Get-ForbiddenActions($stageKey) {
    if ($stageKey -eq 'attachment_copy') {
        return @(
            'Do not copy attachments without explicit -Execute approval.',
            'Do not write recovered files into the legacy public upload directory.',
            'Do not mark missing files as recovered without evidence or approved exception notes.'
        )
    }
    if ($stageKey -eq 'project_files') {
        return @(
            'Do not import project file records with pending project_id mapping.',
            'Do not create placeholder project ids to bypass dry-run validation.',
            'Do not expose migrated attachments without download permission checks.'
        )
    }
    return @('Do not perform production writes before the matching dry-run report is ready.')
}

function Get-ValidationChecks($stageKey) {
    if ($stageKey -eq 'attachment_copy') {
        return @(
            'legacy-attachment-import-dry-run.json has blocked_items=0 or approved exceptions cover all blocked items.',
            'legacy-attachment-import-execute.json exists after the explicit execute window.',
            'Copied count, blocked count, and byte totals are reviewed by ops_owner.'
        )
    }
    if ($stageKey -eq 'project_files') {
        return @(
            'legacy-project-id-map.resolved.json has blocked_projects=0.',
            'legacy-project-file-db-dry-run.resolved.json has blocked_records=0.',
            'Project file import preview shows only rows with mapped project ids and authorized attachment references.'
        )
    }
    return @('The matching dry-run report has no blockers and the preflight item is no longer blocker.')
}

function Get-ManualCommands($stageKey) {
    if ($stageKey -eq 'attachment_copy') {
        return @(
            'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyAttachmentImportDryRun.ps1',
            'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyAttachmentImportDryRun.ps1 -Execute'
        )
    }
    if ($stageKey -eq 'project_files') {
        return @(
            'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\New-LegacyResolvedMappingReports.ps1',
            'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyResolvedMappingDryRun.ps1'
        )
    }
    return @('PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1 -WithMock')
}

$batchPlan = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-batch-plan.json')
$actionSheet = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-action-sheet.json')
$preflight = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json')

$items = New-Object System.Collections.Generic.List[object]
$stageActionKeys = @{
    attachment_copy = @('attachment_execute_required', 'attachment_copy_blocked_items', 'missing_attachments')
    project_files = @('project_id_mapping', 'project_file_blocked_records', 'attachment_copy_blocked_items')
}

foreach ($stage in @($batchPlan.stages | Where-Object { $_.status -eq 'blocked' -or $_.status -eq 'missing' })) {
    $keys = if ($stageActionKeys.ContainsKey($stage.key)) { $stageActionKeys[$stage.key] } else { @() }
    $relatedActions = Find-ActionItems $actionSheet $keys
    $preflightItems = @($preflight.items | Where-Object { $_.source -eq $stage.key -and $_.severity -eq 'blocker' })
    $owners = @($relatedActions | ForEach-Object { $_.owner } | Select-Object -Unique)
    $evidence = @($relatedActions | ForEach-Object { $_.source } | Select-Object -Unique)
    $actionTitles = @($relatedActions | ForEach-Object { $_.title })

    $items.Add([pscustomobject][ordered]@{
        stage = $stage.key
        status = $stage.status
        severity = 'blocker'
        owner = Join-Values $owners
        planned_count = Get-Number $stage.planned_count
        ready_count = Get-Number $stage.ready_count
        waiting_count = Get-Number $stage.waiting_count
        blocked_count = Get-Number $stage.blocked_count
        dependencies = @($stage.dependencies)
        warnings = @($stage.warnings)
        related_action_keys = @($keys)
        related_action_titles = @($actionTitles)
        preflight_titles = @($preflightItems | ForEach-Object { $_.title })
        evidence_reports = @($evidence)
        allowed_actions = @(Get-AllowedActions $stage.key)
        forbidden_actions = @(Get-ForbiddenActions $stage.key)
        validation_checks = @(Get-ValidationChecks $stage.key)
        manual_commands = @(Get-ManualCommands $stage.key)
    })
}

$blockers = @($items.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$csvRows = @($items.ToArray() | ForEach-Object {
    [pscustomobject][ordered]@{
        stage = $_.stage
        status = $_.status
        owner = $_.owner
        planned_count = $_.planned_count
        ready_count = $_.ready_count
        waiting_count = $_.waiting_count
        blocked_count = $_.blocked_count
        dependencies = Join-Values $_.dependencies
        warnings = Join-Values $_.warnings
        related_action_keys = Join-Values $_.related_action_keys
        evidence_reports = Join-Values $_.evidence_reports
        allowed_actions = Join-Values $_.allowed_actions
        forbidden_actions = Join-Values $_.forbidden_actions
        validation_checks = Join-Values $_.validation_checks
        manual_commands = Join-Values $_.manual_commands
    }
})

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add('# Legacy Migration Blocker Resolution Pack')
$markdown.Add('')
$markdown.Add('This pack is preview-only. It does not copy files, import records, update templates, or write database records.')
$markdown.Add('')
$markdown.Add("Generated at: $(Get-Date -Format o)")
$markdown.Add("Blocked stages: $blockers")
$markdown.Add('')
foreach ($item in @($items.ToArray())) {
    $markdown.Add("## $($item.stage)")
    $markdown.Add('')
    $markdown.Add("- Owner: $($item.owner)")
    $markdown.Add("- Counts: planned=$($item.planned_count), ready=$($item.ready_count), waiting=$($item.waiting_count), blocked=$($item.blocked_count)")
    $markdown.Add("- Dependencies: $(Join-Values $item.dependencies)")
    $markdown.Add("- Evidence: $(Join-Values $item.evidence_reports)")
    $markdown.Add("- Allowed actions: $(Join-Values $item.allowed_actions)")
    $markdown.Add("- Forbidden actions: $(Join-Values $item.forbidden_actions)")
    $markdown.Add("- Validation checks: $(Join-Values $item.validation_checks)")
    $markdown.Add("- Manual commands: $(Join-Values $item.manual_commands)")
    $markdown.Add('')
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This pack summarizes blocked migration stages and approved resolution steps. It does not copy files, import records, update templates, or write database records.'
    overall_status = if ($blockers -gt 0) { 'blocked' } else { 'ready' }
    summary = [ordered]@{
        blocked_stages = $blockers
        total_items = $items.Count
        csv_exists = $true
        markdown_exists = $true
    }
    source_reports = [ordered]@{
        batch_plan = [bool]$batchPlan
        blocker_action_sheet = [bool]$actionSheet
        preflight_checklist = [bool]$preflight
    }
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$csvRows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
$markdown | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

Write-Host "Legacy migration blocker resolution pack written to $ReportPath"
Write-Host "Legacy migration blocker resolution pack CSV written to $CsvPath"
Write-Host "Legacy migration blocker resolution pack Markdown written to $MarkdownPath"
