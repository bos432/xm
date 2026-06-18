param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-action-sheet.json"),
    [int]$SampleSize = 20
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

function Get-List($values) {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($value in @($values)) {
        if ($null -ne $value) { $items.Add($value) }
    }
    return @($items.ToArray())
}

function New-ActionItem($key, $severity, $owner, $title, $count, $source, $action, $acceptance, $samples) {
    return [ordered]@{
        key = $key
        severity = $severity
        owner = $owner
        title = $title
        affected_count = Get-Number $count
        source = $source
        action = $action
        acceptance = $acceptance
        samples = @(Get-List $samples | Select-Object -First $SampleSize)
    }
}

function New-UnitSamples($unitUserMap) {
    $samples = New-Object System.Collections.Generic.List[object]
    if (-not $unitUserMap) { return @() }
    foreach ($item in @(Get-List $unitUserMap.samples.pending)) {
        $samples.Add([ordered]@{
            legacy_unit_id = $item.legacy_unit_id
            project_count = $item.project_count
            warnings = @($item.warnings)
            expected_mapping = 'unit_id and owner_id'
        })
    }
    return @($samples.ToArray())
}

function New-ProjectSamples($projectIdMap) {
    $samples = New-Object System.Collections.Generic.List[object]
    if (-not $projectIdMap) { return @() }
    foreach ($item in @(Get-List $projectIdMap.samples.pending)) {
        $samples.Add([ordered]@{
            legacy_project_id = $item.legacy_project_id
            attachment_count = $item.attachment_count
            ready_attachment_count = $item.ready_attachment_count
            blocked_attachment_count = $item.blocked_attachment_count
            expected_mapping = 'new_project_id'
        })
    }
    return @($samples.ToArray())
}

function New-AttachmentSamples($attachmentQuality) {
    $samples = New-Object System.Collections.Generic.List[object]
    if (-not $attachmentQuality) { return @() }
    foreach ($item in @(Get-List $attachmentQuality.samples.missing)) {
        $samples.Add([ordered]@{
            source_table = $item.source_table
            legacy_project_id = $item.legacy_project_id
            legacy_id = $item.legacy_id
            field = $item.field
            path = $item.path
            original_name = $item.original_name
            warnings = @($item.warnings)
        })
    }
    return @($samples.ToArray())
}

function New-ProjectFileSamples($projectFileDb) {
    $samples = New-Object System.Collections.Generic.List[object]
    if (-not $projectFileDb) { return @() }
    foreach ($item in @(Get-List $projectFileDb.samples.blocked)) {
        $samples.Add([ordered]@{
            legacy_id = $item.legacy_id
            legacy_project_id = $item.legacy_project_id
            path = $item.path
            original_name = $item.original_name
            warnings = @($item.warnings)
        })
    }
    return @($samples.ToArray())
}

$recordImportPlan = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-record-import-plan.json')
$unitUserMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-id-map.json')
$projectIdMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-id-map.json')
$attachmentQuality = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-quality.json')
$attachmentDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-dry-run.json')
$projectFileDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')

$blockerCounts = if ($recordImportPlan) { $recordImportPlan.summary.blocker_counts } else { $null }
$items = New-Object System.Collections.Generic.List[object]

$pendingUnits = if ($unitUserMap) { Get-Number $unitUserMap.summary.pending_units } else { Get-Number $blockerCounts.unit_id_mapping_required }
if ($pendingUnits -gt 0) {
    $items.Add((New-ActionItem `
        'unit_user_mapping' `
        'blocker' `
        'data_migration_owner' `
        'Create production unit and owner id mapping' `
        $pendingUnits `
        'legacy-unit-user-id-map.json' `
        'Import or create units and owner users first, then replace pending unit_id and owner_id values in legacy-unit-user-id-map.json.' `
        'legacy-unit-user-id-map.json has pending_units=0; legacy-project-db-dry-run.json reports ready_for_import equals total_records in mock-free production mapping.' `
        (New-UnitSamples $unitUserMap)))
}

$pendingProjects = if ($projectIdMap) { Get-Number $projectIdMap.summary.pending_projects } else { Get-Number $blockerCounts.project_id_mapping_required }
if ($pendingProjects -gt 0) {
    $items.Add((New-ActionItem `
        'project_id_mapping' `
        'blocker' `
        'data_migration_owner' `
        'Create production project id mapping' `
        $pendingProjects `
        'legacy-project-id-map.json' `
        'Import projects first, then replace pending new_project_id values in legacy-project-id-map.json.' `
        'legacy-project-id-map.json has pending_projects=0; legacy-project-file-db-dry-run.json ready_for_project_mapping is 0.' `
        (New-ProjectSamples $projectIdMap)))
}

$missingFiles = if ($attachmentQuality) { Get-Number $attachmentQuality.summary.missing_files } else { Get-Number $blockerCounts.missing_file }
if ($missingFiles -gt 0) {
    $items.Add((New-ActionItem `
        'missing_attachments' `
        'warning' `
        'business_owner' `
        'Resolve missing legacy attachments' `
        $missingFiles `
        'legacy-attachment-quality.json' `
        'Recover files from backup if available. If unrecoverable, approve a documented exception with legacy project id, field, and reason.' `
        'legacy-attachment-quality.json missing_files is 0, or each missing item has an approved exception recorded before go-live.' `
        (New-AttachmentSamples $attachmentQuality)))
}

$blockedProjectFiles = if ($projectFileDb) { Get-Number $projectFileDb.summary.blocked_records } else { 0 }
if ($blockedProjectFiles -gt 0) {
    $items.Add((New-ActionItem `
        'project_file_blocked_records' `
        'warning' `
        'data_migration_owner' `
        'Resolve blocked project file DB records' `
        $blockedProjectFiles `
        'legacy-project-file-db-dry-run.json' `
        'Fix missing attachment references or record approved exceptions, then regenerate project file DB dry-run.' `
        'legacy-project-file-db-dry-run.json blocked_records is 0, or exceptions are reviewed and accepted.' `
        (New-ProjectFileSamples $projectFileDb)))
}

$attachmentBlocked = if ($attachmentDryRun) { Get-Number $attachmentDryRun.summary.blocked_items } else { 0 }
if ($attachmentBlocked -gt 0) {
    $items.Add((New-ActionItem `
        'attachment_copy_blocked_items' `
        'warning' `
        'ops_owner' `
        'Resolve attachment copy dry-run blocked items' `
        $attachmentBlocked `
        'legacy-attachment-import-dry-run.json' `
        'Review blocked copy plans. Recover source files, correct path mapping, or approve exceptions before Execute copy.' `
        'legacy-attachment-import-dry-run.json blocked_items is 0, or exceptions are approved.' `
        (New-AttachmentSamples $attachmentQuality)))
}

$attachmentExecute = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-execute.json')
if (-not $attachmentExecute) {
    $items.Add((New-ActionItem `
        'attachment_execute_required' `
        'blocker' `
        'ops_owner' `
        'Run explicit attachment copy execute after approval' `
        1 `
        'Invoke-LegacyAttachmentImportDryRun.ps1' `
        'After dry-run approval, run Invoke-LegacyAttachmentImportDryRun.ps1 -Execute during the migration window.' `
        'legacy-attachment-import-execute.json exists and copied count, blocked count, and byte totals are reviewed.' `
        @()))
}

$blockerCount = @($items | Where-Object { $_.severity -eq 'blocker' }).Count
$warningCount = @($items | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    overall_status = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_items = $items.Count
        blockers = $blockerCount
        warnings = $warningCount
        affected_records = @($items | ForEach-Object { Get-Number $_.affected_count } | Measure-Object -Sum).Sum
    }
    source_reports = [ordered]@{
        record_import_plan = [bool]$recordImportPlan
        unit_user_id_map = [bool]$unitUserMap
        project_id_map = [bool]$projectIdMap
        attachment_quality = [bool]$attachmentQuality
        attachment_import_dry_run = [bool]$attachmentDryRun
        project_file_db_dry_run = [bool]$projectFileDb
        attachment_import_execute = [bool]$attachmentExecute
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker action sheet written to $ReportPath"


