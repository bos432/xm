param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-batch-plan.json")
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

function New-Stage($order, $key, $label, $target, $planned, $ready, $waiting, $blocked, $dependencies, $warnings) {
    if ($order -is [array]) {
        $values = @($order)
        $order = $values[0]
        $key = $values[1]
        $label = $values[2]
        $target = $values[3]
        $planned = $values[4]
        $ready = $values[5]
        $waiting = $values[6]
        $blocked = $values[7]
        $dependencies = $values[8]
        $warnings = $values[9]
    }
$status = 'ready'
    if ($planned -eq 0) { $status = 'missing' }
    elseif ($blocked -gt 0) { $status = 'blocked' }
    elseif ($waiting -gt 0) { $status = 'waiting' }

    return [ordered]@{
        order = $order
        key = $key
        label = $label
        target = $target
        status = $status
        planned_count = $planned
        ready_count = $ready
        waiting_count = $waiting
        blocked_count = $blocked
        dependencies = @($dependencies)
        warnings = @($warnings)
    }
}

$unitUserDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.json')
$unitUserDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.mock.json')
$projectDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$projectDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.mock.json')
$attachmentDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-dry-run.json')
$projectFileDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')
$projectFileDbMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.mock.json')

$stages = New-Object System.Collections.Generic.List[object]

if ($unitUserDb) {
    $stages.Add((New-Stage @(
        1, 'units', 'units_import', 'units',
        (Get-Number $unitUserDb.summary.total_units),
        (Get-Number $unitUserDb.summary.ready_units),
        0,
        0,
        @(),
        @()
    )))

    $userWarnings = @()
    if ((Get-Number $unitUserDb.summary.users_waiting_unit_mapping) -gt 0) { $userWarnings += 'unit_user_mapping_required' }
    $stages.Add((New-Stage @(
        2, 'users', 'users_import', 'users',
        (Get-Number $unitUserDb.summary.total_users),
        (Get-Number $unitUserDb.summary.ready_users),
        (Get-Number $unitUserDb.summary.users_waiting_unit_mapping),
        0,
        @('units'),
        $userWarnings
    )))
} else {
    $stages.Add((New-Stage 1 'units' 'units_import' 'units' 0 0 0 0 @() @('report_missing')))
    $stages.Add((New-Stage 2 'users' 'users_import' 'users' 0 0 0 0 @('units') @('report_missing')))
}

if ($projectDb) {
    $projectWarnings = @()
    if ((Get-Number $projectDb.summary.ready_for_unit_user_mapping) -gt 0) { $projectWarnings += 'unit_user_mapping_required' }
    $stages.Add((New-Stage @(
        3, 'projects', 'projects_import', 'projects',
        (Get-Number $projectDb.summary.total_records),
        (Get-Number $projectDb.summary.ready_for_import),
        (Get-Number $projectDb.summary.ready_for_unit_user_mapping),
        0,
        @('units', 'users'),
        $projectWarnings
    )))
} else {
    $stages.Add((New-Stage 3 'projects' 'projects_import' 'projects' 0 0 0 0 @('units', 'users') @('report_missing')))
}

if ($attachmentDryRun) {
    $stages.Add((New-Stage @(
        4, 'attachment_copy', 'attachment_copy', 'storage:private',
        (Get-Number $attachmentDryRun.summary.total_items),
        (Get-Number $attachmentDryRun.summary.ready_items),
        0,
        (Get-Number $attachmentDryRun.summary.blocked_items),
        @('projects'),
        @('execute_required')
    )))
} else {
    $stages.Add((New-Stage 4 'attachment_copy' 'attachment_copy' 'storage:private' 0 0 0 0 @('projects') @('report_missing')))
}

if ($projectFileDb) {
    $projectFileWarnings = @()
    if ((Get-Number $projectFileDb.summary.ready_for_project_mapping) -gt 0) { $projectFileWarnings += 'project_id_mapping_required' }
    $stages.Add((New-Stage @(
        5, 'project_files', 'project_files_import', 'project_files',
        (Get-Number $projectFileDb.summary.total_records),
        (Get-Number $projectFileDb.summary.ready_for_import),
        (Get-Number $projectFileDb.summary.ready_for_project_mapping),
        (Get-Number $projectFileDb.summary.blocked_records),
        @('projects', 'attachment_copy'),
        $projectFileWarnings
    )))
} else {
    $stages.Add((New-Stage 5 'project_files' 'project_files_import' 'project_files' 0 0 0 0 @('projects', 'attachment_copy') @('report_missing')))
}

$blockedStages = @($stages | Where-Object { $_.status -eq 'blocked' }).Count
$waitingStages = @($stages | Where-Object { $_.status -eq 'waiting' }).Count
$missingStages = @($stages | Where-Object { $_.status -eq 'missing' }).Count
$readyStages = @($stages | Where-Object { $_.status -eq 'ready' }).Count

$overallStatus = if ($blockedStages -gt 0 -or $missingStages -gt 0) {
    'blocked'
} elseif ($waitingStages -gt 0) {
    'not_ready'
} else {
    'ready'
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    overall_status = $overallStatus
    summary = [ordered]@{
        total_stages = $stages.Count
        ready_stages = $readyStages
        waiting_stages = $waitingStages
        blocked_stages = $blockedStages
        missing_stages = $missingStages
    }
    mock_validation = [ordered]@{
        users_ready = if ($unitUserDbMock) { Get-Number $unitUserDbMock.summary.ready_users } else { 0 }
        projects_ready = if ($projectDbMock) { Get-Number $projectDbMock.summary.ready_for_import } else { 0 }
        project_files_ready = if ($projectFileDbMock) { Get-Number $projectFileDbMock.summary.ready_for_import } else { 0 }
    }
    stages = @($stages.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration batch plan written to $ReportPath"



