param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-readiness-summary.json")
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

function New-Gate($key, $label, $status, $summary, $warnings = @()) {
    return [ordered]@{
        key = $key
        label = $label
        status = $status
        summary = $summary
        warnings = @($warnings)
    }
}

$attachmentQuality = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-quality.json')
$attachmentDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-dry-run.json')
$projectDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$projectDryRunMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.mock.json')
$projectIdMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-id-map.json')
$unitUserMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-id-map.json')
$projectFileDbDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')
$projectFileDbDryRunMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.mock.json')

$gates = New-Object System.Collections.Generic.List[object]

if ($attachmentQuality) {
    $missingFiles = Get-Number $attachmentQuality.summary.missing_files
    $dangerousExtensions = Get-Number $attachmentQuality.summary.dangerous_extensions
    $status = if ($missingFiles -eq 0 -and $dangerousExtensions -eq 0) { 'pass' } elseif ($dangerousExtensions -gt 0) { 'blocked' } else { 'warning' }
    $warnings = @()
    if ($missingFiles -gt 0) { $warnings += 'attachment_missing_files' }
    if ($dangerousExtensions -gt 0) { $warnings += 'attachment_dangerous_extensions' }
    $gates.Add((New-Gate 'attachment_quality' '附件质量' $status $attachmentQuality.summary $warnings))
} else {
    $gates.Add((New-Gate 'attachment_quality' '附件质量' 'missing' $null @('report_missing')))
}

if ($attachmentDryRun) {
    $blocked = Get-Number $attachmentDryRun.summary.blocked_items
    $targetEscapes = Get-Number $attachmentDryRun.summary.target_path_escapes_root
    $duplicates = Get-Number $attachmentDryRun.summary.duplicate_target_paths
    $status = if ($blocked -eq 0 -and $targetEscapes -eq 0 -and $duplicates -eq 0) { 'pass' } elseif ($targetEscapes -gt 0 -or $duplicates -gt 0) { 'blocked' } else { 'warning' }
    $warnings = @()
    if ($blocked -gt 0) { $warnings += 'attachment_import_blocked_items' }
    if ($targetEscapes -gt 0) { $warnings += 'target_path_escapes_root' }
    if ($duplicates -gt 0) { $warnings += 'duplicate_target_paths' }
    $gates.Add((New-Gate 'attachment_import_dry_run' '附件复制 Dry Run' $status $attachmentDryRun.summary $warnings))
} else {
    $gates.Add((New-Gate 'attachment_import_dry_run' '附件复制 Dry Run' 'missing' $null @('report_missing')))
}

if ($projectDryRun) {
    $readyForImport = Get-Number $projectDryRun.summary.ready_for_import
    $total = Get-Number $projectDryRun.summary.total_records
    $status = if ($total -gt 0 -and $readyForImport -eq $total) { 'pass' } else { 'waiting' }
    $gates.Add((New-Gate 'project_db_dry_run' '项目核心数据' $status $projectDryRun.summary @('unit_user_mapping_required')))
} else {
    $gates.Add((New-Gate 'project_db_dry_run' '项目核心数据' 'missing' $null @('report_missing')))
}

if ($projectIdMap) {
    $pending = Get-Number $projectIdMap.summary.pending_projects
    $status = if ($pending -eq 0) { 'pass' } else { 'waiting' }
    $gates.Add((New-Gate 'project_id_map' '项目 ID 映射' $status $projectIdMap.summary @($(if ($pending -gt 0) { 'project_id_mapping_required' }))))
} else {
    $gates.Add((New-Gate 'project_id_map' '项目 ID 映射' 'missing' $null @('report_missing')))
}

if ($unitUserMap) {
    $pending = Get-Number $unitUserMap.summary.pending_units
    $status = if ($pending -eq 0) { 'pass' } else { 'waiting' }
    $gates.Add((New-Gate 'unit_user_id_map' '单位/用户 ID 映射' $status $unitUserMap.summary @($(if ($pending -gt 0) { 'unit_user_mapping_required' }))))
} else {
    $gates.Add((New-Gate 'unit_user_id_map' '单位/用户 ID 映射' 'missing' $null @('report_missing')))
}

if ($projectFileDbDryRun) {
    $readyForImport = Get-Number $projectFileDbDryRun.summary.ready_for_import
    $blocked = Get-Number $projectFileDbDryRun.summary.blocked_records
    $status = if ($readyForImport -gt 0 -and $blocked -eq 0) { 'pass' } elseif ($blocked -gt 0) { 'warning' } else { 'waiting' }
    $warnings = @()
    if ($blocked -gt 0) { $warnings += 'project_file_blocked_records' }
    if ($readyForImport -eq 0) { $warnings += 'project_file_mapping_required' }
    $gates.Add((New-Gate 'project_file_db_dry_run' '附件入库记录' $status $projectFileDbDryRun.summary $warnings))
} else {
    $gates.Add((New-Gate 'project_file_db_dry_run' '附件入库记录' 'missing' $null @('report_missing')))
}

$blockedCount = @($gates | Where-Object { $_.status -eq 'blocked' }).Count
$missingCount = @($gates | Where-Object { $_.status -eq 'missing' }).Count
$waitingCount = @($gates | Where-Object { $_.status -eq 'waiting' }).Count
$warningCount = @($gates | Where-Object { $_.status -eq 'warning' }).Count
$passCount = @($gates | Where-Object { $_.status -eq 'pass' }).Count

$overallStatus = if ($blockedCount -gt 0 -or $missingCount -gt 0) {
    'blocked'
} elseif ($waitingCount -gt 0 -or $warningCount -gt 0) {
    'not_ready'
} else {
    'ready'
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    overall_status = $overallStatus
    summary = [ordered]@{
        total_gates = $gates.Count
        pass = $passCount
        warning = $warningCount
        waiting = $waitingCount
        blocked = $blockedCount
        missing = $missingCount
    }
    mock_validation = [ordered]@{
        project_ready_for_import = if ($projectDryRunMock) { Get-Number $projectDryRunMock.summary.ready_for_import } else { 0 }
        project_file_ready_for_import = if ($projectFileDbDryRunMock) { Get-Number $projectFileDbDryRunMock.summary.ready_for_import } else { 0 }
    }
    gates = @($gates.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration readiness summary written to $ReportPath"
