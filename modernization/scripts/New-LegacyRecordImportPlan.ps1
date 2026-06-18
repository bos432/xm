param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-record-import-plan.json"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Convert-ToHashtable($object) {
    $result = [ordered]@{}
    if ($null -eq $object) { return $result }
    foreach ($property in $object.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }
    return $result
}

function Get-StringList($values) {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($values)) {
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            $items.Add([string]$value)
        }
    }
    return @($items.ToArray())
}

function Test-ReadyStatus($status) {
    return @('ready', 'ready_for_import') -contains [string]$status
}

function Get-Blockers($status, $warnings) {
    $blockers = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @(Get-StringList $warnings)) {
        if ($warning -eq 'password_reset_required') { continue }
        if ($warning.Contains('mapping_required') -or $warning.Contains('missing') -or $warning.Contains('blocked')) {
            $blockers.Add($warning)
        }
    }
    if (-not (Test-ReadyStatus $status)) {
        $blockers.Add(('status:' + [string]$status))
    }
    return @($blockers.ToArray() | Select-Object -Unique)
}

function Test-AllowedProjectFileDisk($source) {
    if (-not $source.Contains('disk')) { return $false }
    return @('local', 'private') -contains [string]$source['disk']
}

function Test-AllowedProjectFilePath($source) {
    if (-not $source.Contains('path') -or [string]::IsNullOrWhiteSpace([string]$source['path'])) { return $false }

    $path = [string]$source['path']
    $normalized = $path.Replace('\', '/')
    if ($normalized -ne $path) { return $false }
    if ($normalized.StartsWith('/')) { return $false }
    if ($normalized.Contains('../') -or $normalized.Contains('/..')) { return $false }

    $projectId = if ($source.Contains('project_id')) { [string]$source['project_id'] } else { '' }
    return $normalized.StartsWith("project-files/$projectId/") -or $normalized.StartsWith('legacy/projects/')
}

function Select-Attributes($record, $fields) {
    $source = Convert-ToHashtable $record
    $attributes = [ordered]@{}
    foreach ($field in $fields) {
        if ($source.Contains($field)) {
            $attributes[$field] = $source[$field]
        }
    }
    return $attributes
}

function Get-Lookup($table, $record) {
    $source = Convert-ToHashtable $record
    if ($source.Contains('legacy_id') -and $null -ne $source['legacy_id'] -and [string]$source['legacy_id'] -ne '') {
        return [ordered]@{ legacy_id = $source['legacy_id'] }
    }
    if ($table -eq 'users' -and $source.Contains('username') -and -not [string]::IsNullOrWhiteSpace([string]$source['username'])) {
        return [ordered]@{ username = $source['username'] }
    }
    if ($table -eq 'migration_batches' -and $source.Contains('name') -and -not [string]::IsNullOrWhiteSpace([string]$source['name'])) {
        return [ordered]@{ name = $source['name'] }
    }
    if ($table -eq 'migration_batch_items') {
        return [ordered]@{ legacy_table = $source['legacy_table']; target_table = $source['target_table'] }
    }
    return [ordered]@{}
}

function New-PlannedRecord($table, $record, $fields, $references = [ordered]@{}) {
    $source = Convert-ToHashtable $record
    $status = if ($source.Contains('db_status')) { [string]$source['db_status'] } elseif ($source.Contains('status')) { [string]$source['status'] } else { 'unknown' }
    $warnings = if ($source.Contains('warnings')) { Get-StringList $source['warnings'] } else { @() }
    $blockers = Get-Blockers $status $warnings
    if ($table -eq 'project_files') {
        if (-not (Test-AllowedProjectFileDisk $source)) {
            $blockers += 'project_file.invalid_disk'
        }
        if (-not (Test-AllowedProjectFilePath $source)) {
            $blockers += 'project_file.invalid_path'
        }
        $blockers = @($blockers | Select-Object -Unique)
    }
    return [ordered]@{
        action = 'upsert'
        target_table = $table
        lookup = Get-Lookup $table $record
        status = $status
        is_ready = ((Test-ReadyStatus $status) -and $blockers.Count -eq 0)
        attributes = Select-Attributes $record $fields
        references = $references
        warnings = @($warnings)
        blockers = @($blockers)
    }
}

function New-Summary($target, $tables, $records) {
    $statusCounts = [ordered]@{}
    $blockerCounts = [ordered]@{}
    $readyCount = 0
    $blockedCount = 0
    foreach ($record in @($records)) {
        $status = [string]$record.status
        if (-not $statusCounts.Contains($status)) { $statusCounts[$status] = 0 }
        $statusCounts[$status]++
        if ($record.is_ready) { $readyCount++ }
        if (@($record.blockers).Count -gt 0) {
            $blockedCount++
            foreach ($blocker in @($record.blockers)) {
                $key = [string]$blocker
                if (-not $blockerCounts.Contains($key)) { $blockerCounts[$key] = 0 }
                $blockerCounts[$key]++
            }
        }
    }
    return [ordered]@{
        target = $target
        mode = 'dry_run'
        target_tables = @($tables)
        planned_records = @($records).Count
        ready_records = $readyCount
        blocked_records = $blockedCount
        waiting_records = [Math]::Max(0, @($records).Count - $readyCount - $blockedCount)
        status_counts = $statusCounts
        blocker_counts = $blockerCounts
    }
}

function Get-ReportRecords($report, $key) {
    if ($null -eq $report) { return @() }
    if ($report.PSObject.Properties.Name -contains $key) { return @($report.$key) }
    if ($report.samples -and ($report.samples.PSObject.Properties.Name -contains $key)) { return @($report.samples.$key) }
    if ($key -eq 'records' -and $report.samples) {
        $records = New-Object System.Collections.Generic.List[object]
        foreach ($property in $report.samples.PSObject.Properties) {
            foreach ($record in @($property.Value)) { if ($record) { $records.Add($record) } }
        }
        return @($records.ToArray())
    }
    return @()
}

$fields = @{
    units = @('legacy_id', 'name', 'credit_code', 'contact_name', 'contact_mobile', 'email', 'address', 'region_code', 'status', 'metadata')
    users = @('name', 'username', 'email', 'mobile', 'password', 'role', 'unit_id', 'is_active')
    projects = @('legacy_id', 'unit_id', 'owner_id', 'title', 'category', 'project_type', 'status', 'summary', 'budget_amount', 'submitted_at', 'current_reviewer_role', 'metadata')
    project_files = @('legacy_id', 'project_id', 'uploaded_by', 'disk', 'path', 'original_name', 'mime_type', 'extension', 'size_bytes', 'sha256', 'purpose', 'metadata')
    migration_batches = @('name', 'mode', 'source_path', 'status', 'started_at', 'finished_at', 'summary', 'metadata')
    migration_batch_items = @('migration_batch_id', 'legacy_table', 'target_table', 'status', 'create_found', 'insert_statement_count', 'estimated_row_count', 'warning_count', 'metadata')
}

$unitUserDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.json')
$projectDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$projectFileDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')
$migrationBatchDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-batch-db-dry-run.json')

$targets = New-Object System.Collections.Generic.List[object]
$allRecords = New-Object System.Collections.Generic.List[object]

$targetDefinitions = @(
    [ordered]@{ key = 'units'; table = 'units'; report = $unitUserDb; record_key = 'units'; tables = @('units') },
    [ordered]@{ key = 'users'; table = 'users'; report = $unitUserDb; record_key = 'users'; tables = @('users') },
    [ordered]@{ key = 'projects'; table = 'projects'; report = $projectDb; record_key = 'records'; tables = @('projects') },
    [ordered]@{ key = 'project_files'; table = 'project_files'; report = $projectFileDb; record_key = 'records'; tables = @('project_files') }
)

foreach ($definition in $targetDefinitions) {
    $planned = New-Object System.Collections.Generic.List[object]
    foreach ($record in @(Get-ReportRecords $definition.report $definition.record_key)) {
        if ($null -eq $record) { continue }
        $plannedRecord = New-PlannedRecord $definition.table $record $fields[$definition.table]
        $planned.Add($plannedRecord)
        $allRecords.Add($plannedRecord)
    }
    $targets.Add([ordered]@{
        target = $definition.key
        source_report = if ($definition.report) { $definition.report.generated_at } else { $null }
        summary = New-Summary $definition.key $definition.tables @($planned.ToArray())
        sample_records = @($planned.ToArray() | Select-Object -First $SampleSize)
    })
}

$batchPlanned = New-Object System.Collections.Generic.List[object]
if ($migrationBatchDb -and $migrationBatchDb.batch) {
    $batchRecord = New-PlannedRecord 'migration_batches' $migrationBatchDb.batch $fields['migration_batches']
    $batchPlanned.Add($batchRecord)
    $allRecords.Add($batchRecord)
}
if ($migrationBatchDb) {
    foreach ($record in @($migrationBatchDb.items)) {
        if ($null -eq $record) { continue }
        $refs = [ordered]@{ migration_batch_name = if ($migrationBatchDb.batch) { $migrationBatchDb.batch.name } else { $null } }
        $plannedRecord = New-PlannedRecord 'migration_batch_items' $record $fields['migration_batch_items'] $refs
        $batchPlanned.Add($plannedRecord)
        $allRecords.Add($plannedRecord)
    }
}
$targets.Add([ordered]@{
    target = 'migration_batches'
    source_report = if ($migrationBatchDb) { $migrationBatchDb.generated_at } else { $null }
    summary = New-Summary 'migration_batches' @('migration_batches', 'migration_batch_items') @($batchPlanned.ToArray())
    sample_records = @($batchPlanned.ToArray() | Select-Object -First $SampleSize)
})

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'dry_run'
    note = 'This report is an import plan preview only. It does not copy files, connect to MySQL, or write application tables.'
    summary = New-Summary 'all' @('units', 'users', 'projects', 'project_files', 'migration_batches', 'migration_batch_items') @($allRecords.ToArray())
    targets = @($targets.ToArray())
}

$report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy record import plan written to $ReportPath"
