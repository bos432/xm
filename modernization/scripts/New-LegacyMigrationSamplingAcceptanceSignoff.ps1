param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff.csv"),
    [int]$SampleSize = 5
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Get-Field($row, $name, $default = '') {
    if ($null -eq $row) { return $default }
    if ($row.PSObject.Properties.Name -contains $name) { return $row.$name }
    return $default
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function New-Sample($category, $sampleKey, $legacyId, $target, $title, $source, $expectedChecks, $riskNotes) {
    return [pscustomobject][ordered]@{
        category = $category
        sample_key = $sampleKey
        legacy_id = $legacyId
        target = $target
        title = $title
        source = $source
        expected_checks = $expectedChecks
        risk_notes = $riskNotes
    }
}

function Add-RecordSamples($samples, $category, $records, $target, $source, $titleField, $checks, $riskField, $limit) {
    $count = 0
    foreach ($record in @($records)) {
        if ($count -ge $limit) { break }
        $legacyId = [string]$record.legacy_id
        if (Test-Blank $legacyId) { continue }
        $sampleKey = "$category`:$legacyId"
        $title = if ($record.PSObject.Properties.Name -contains $titleField) { [string]$record.$titleField } else { $sampleKey }
        $risk = if ($record.PSObject.Properties.Name -contains $riskField) { (@($record.$riskField) -join '; ') } else { '' }
        $samples.Add((New-Sample $category $sampleKey $legacyId $target $title $source $checks $risk))
        $count++
    }
}

function New-SignoffRow($sample, $existingRow) {
    $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    return [pscustomobject][ordered]@{
        status = $status
        category = $sample.category
        sample_key = $sample.sample_key
        legacy_id = $sample.legacy_id
        target = $sample.target
        title = $sample.title
        source = $sample.source
        expected_checks = $sample.expected_checks
        risk_notes = $sample.risk_notes
        sampled_by = Get-Field $existingRow 'sampled_by'
        sampled_at = Get-Field $existingRow 'sampled_at'
        evidence_ref = Get-Field $existingRow 'evidence_ref'
        notes = Get-Field $existingRow 'notes'
    }
}

$unitUserDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.json')
$projectDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$projectFileDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')
$legacyImportDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-import-dry-run.json')
$workflowDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-workflow-db-dry-run.json')

$samples = New-Object System.Collections.Generic.List[object]

if ($unitUserDryRun) {
    Add-RecordSamples $samples 'units' $unitUserDryRun.units 'units' 'legacy-unit-user-db-dry-run.json' 'name' 'legacy id, unit name, credit code, contact, region, status, warning list' 'warnings' $SampleSize
}

if ($projectDryRun) {
    Add-RecordSamples $samples 'projects' $projectDryRun.records 'projects' 'legacy-project-db-dry-run.json' 'title' 'legacy id, title, unit mapping, owner mapping, status, budget, submitted date, warning list' 'warnings' $SampleSize
}

if ($projectFileDryRun) {
    $fileRecords = @($projectFileDryRun.records | Sort-Object @{ Expression = { if ($_.db_status -eq 'blocked') { 0 } else { 1 } } }, legacy_id)
    Add-RecordSamples $samples 'attachments' $fileRecords 'project_files' 'legacy-project-file-db-dry-run.json' 'original_name' 'legacy file id, project mapping, original name, target private path, size, extension, attachment dry-run status' 'warnings' $SampleSize
}

if ($workflowDryRun) {
    Add-RecordSamples $samples 'workflow_reviews' $workflowDryRun.reviews 'project_reviews' 'legacy-workflow-db-dry-run.json' 'decision' 'legacy review id, project mapping, reviewer legacy id, stage, decision, comment excerpt, reviewed time, warning list' 'warnings' $SampleSize
    Add-RecordSamples $samples 'workflow_logs' $workflowDryRun.operation_logs 'operation_logs' 'legacy-workflow-db-dry-run.json' 'action' 'legacy log id, actor legacy id, actor kind, action, ip, occurred time, warning list' 'warnings' $SampleSize
} elseif ($legacyImportDryRun) {
    foreach ($item in @($legacyImportDryRun.items | Where-Object { $_.legacy_table -in @('pro_review', 'pro_check_log', 'pro_log') })) {
        $sampleKey = "workflow:$($item.legacy_table)"
        $checks = 'table exists, estimated row count, target table, import status, warning list; row-level workflow reconstruction is not implemented yet'
        $risk = "estimated_row_count=$($item.estimated_row_count); warnings=$(@($item.warnings) -join '; ')"
        $samples.Add((New-Sample 'workflow' $sampleKey $item.legacy_table $item.target_table $item.legacy_table 'legacy-import-dry-run.json' $checks $risk))
    }
}

$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = ([string](Get-Field $row 'sample_key')).Trim().ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'pass', 'accepted_with_risk', 'fail', 'blocked')
foreach ($sample in @($samples.ToArray())) {
    $key = ([string]$sample.sample_key).Trim().ToLowerInvariant()
    $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
    $rows.Add((New-SignoffRow $sample $existingRow))
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pending = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$passed = @($rows.ToArray() | Where-Object { $_.status -eq 'pass' }).Count
$riskAccepted = @($rows.ToArray() | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$failed = @($rows.ToArray() | Where-Object { $_.status -eq 'fail' }).Count
$blocked = @($rows.ToArray() | Where-Object { $_.status -eq 'blocked' }).Count
$invalid = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$categoryCounts = [ordered]@{}
foreach ($row in @($rows.ToArray())) {
    if (-not $categoryCounts.Contains($row.category)) { $categoryCounts[$row.category] = 0 }
    $categoryCounts[$row.category]++
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks business sampling acceptance. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($invalid -gt 0 -or $failed -gt 0 -or $blocked -gt 0) { 'blocked' } elseif (($passed + $riskAccepted) -eq $rows.Count -and $rows.Count -gt 0) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        sample_items = $rows.Count
        pending_items = $pending
        passed_items = $passed
        accepted_with_risk_items = $riskAccepted
        failed_items = $failed
        blocked_items = $blocked
        invalid_items = $invalid
        category_counts = $categoryCounts
    }
    csv_path = $CsvPath
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration sampling acceptance signoff written to $ReportPath"
Write-Host "Legacy migration sampling acceptance signoff CSV written to $CsvPath"
