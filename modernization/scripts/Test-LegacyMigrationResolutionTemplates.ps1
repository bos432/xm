param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-validation.json"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Test-PositiveInteger($value) {
    if (Test-Blank $value) { return $false }
    return [regex]::IsMatch([string]$value, '^[1-9][0-9]*$')
}

function Add-Issue($issues, $template, $severity, $rowNumber, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        template = $template
        severity = $severity
        row_number = $rowNumber
        field = $field
        code = $code
        message = $message
    })
}

function Test-RequiredColumns($template, $rows, $requiredColumns, $issues) {
    if (@($rows).Count -eq 0) { return }
    $columns = @($rows[0].PSObject.Properties.Name)
    foreach ($column in $requiredColumns) {
        if ($columns -notcontains $column) {
            Add-Issue $issues $template 'blocker' 1 $column 'missing_column' "Missing required column: $column"
        }
    }
}

function Test-DuplicateFilledValue($template, $rows, $field, $issues) {
    $seen = @{}
    for ($i = 0; $i -lt @($rows).Count; $i++) {
        $value = [string]$rows[$i].$field
        if (Test-Blank $value) { continue }
        if (-not $seen.ContainsKey($value)) { $seen[$value] = @() }
        $seen[$value] += ($i + 2)
    }
    foreach ($entry in $seen.GetEnumerator()) {
        if (@($entry.Value).Count -gt 1) {
            foreach ($rowNumber in @($entry.Value)) {
                Add-Issue $issues $template 'blocker' $rowNumber $field 'duplicate_value' "Duplicate $field value: $($entry.Key)"
            }
        }
    }
}

function Test-UnitRows($rows, $issues) {
    Test-RequiredColumns 'unit_user_mapping_template' $rows @('legacy_unit_id', 'unit_id', 'owner_id', 'approved_by') $issues
    Test-DuplicateFilledValue 'unit_user_mapping_template' $rows 'unit_id' $issues
    Test-DuplicateFilledValue 'unit_user_mapping_template' $rows 'owner_id' $issues
    for ($i = 0; $i -lt @($rows).Count; $i++) {
        $row = $rows[$i]
        $rowNumber = $i + 2
        if (-not (Test-PositiveInteger $row.legacy_unit_id)) { Add-Issue $issues 'unit_user_mapping_template' 'blocker' $rowNumber 'legacy_unit_id' 'invalid_integer' 'legacy_unit_id must be a positive integer.' }
        if (Test-Blank $row.unit_id) { Add-Issue $issues 'unit_user_mapping_template' 'warning' $rowNumber 'unit_id' 'value_required' 'unit_id is required before production import.' }
        elseif (-not (Test-PositiveInteger $row.unit_id)) { Add-Issue $issues 'unit_user_mapping_template' 'blocker' $rowNumber 'unit_id' 'invalid_integer' 'unit_id must be a positive integer.' }
        if (Test-Blank $row.owner_id) { Add-Issue $issues 'unit_user_mapping_template' 'warning' $rowNumber 'owner_id' 'value_required' 'owner_id is required before production import.' }
        elseif (-not (Test-PositiveInteger $row.owner_id)) { Add-Issue $issues 'unit_user_mapping_template' 'blocker' $rowNumber 'owner_id' 'invalid_integer' 'owner_id must be a positive integer.' }
        if (Test-Blank $row.approved_by) { Add-Issue $issues 'unit_user_mapping_template' 'warning' $rowNumber 'approved_by' 'approval_required' 'approved_by is required for audit trail.' }
    }
}

function Test-ProjectRows($rows, $issues) {
    Test-RequiredColumns 'project_mapping_template' $rows @('legacy_project_id', 'new_project_id', 'approved_by') $issues
    Test-DuplicateFilledValue 'project_mapping_template' $rows 'new_project_id' $issues
    for ($i = 0; $i -lt @($rows).Count; $i++) {
        $row = $rows[$i]
        $rowNumber = $i + 2
        if (-not (Test-PositiveInteger $row.legacy_project_id)) { Add-Issue $issues 'project_mapping_template' 'blocker' $rowNumber 'legacy_project_id' 'invalid_integer' 'legacy_project_id must be a positive integer.' }
        if (Test-Blank $row.new_project_id) { Add-Issue $issues 'project_mapping_template' 'warning' $rowNumber 'new_project_id' 'value_required' 'new_project_id is required before project file import.' }
        elseif (-not (Test-PositiveInteger $row.new_project_id)) { Add-Issue $issues 'project_mapping_template' 'blocker' $rowNumber 'new_project_id' 'invalid_integer' 'new_project_id must be a positive integer.' }
        if (Test-Blank $row.approved_by) { Add-Issue $issues 'project_mapping_template' 'warning' $rowNumber 'approved_by' 'approval_required' 'approved_by is required for audit trail.' }
    }
}

function Test-AttachmentRows($rows, $issues) {
    Test-RequiredColumns 'attachment_exception_template' $rows @('legacy_project_id', 'decision', 'approved_by') $issues
    for ($i = 0; $i -lt @($rows).Count; $i++) {
        $row = $rows[$i]
        $rowNumber = $i + 2
        if (-not (Test-PositiveInteger $row.legacy_project_id)) { Add-Issue $issues 'attachment_exception_template' 'blocker' $rowNumber 'legacy_project_id' 'invalid_integer' 'legacy_project_id must be a positive integer.' }
        $decision = ([string]$row.decision).Trim().ToLowerInvariant()
        if (Test-Blank $decision) { Add-Issue $issues 'attachment_exception_template' 'warning' $rowNumber 'decision' 'decision_required' 'decision must be recover or exception.' }
        elseif (@('recover', 'exception') -notcontains $decision) { Add-Issue $issues 'attachment_exception_template' 'blocker' $rowNumber 'decision' 'invalid_decision' 'decision must be recover or exception.' }
        elseif ($decision -eq 'recover' -and (Test-Blank $row.replacement_path)) { Add-Issue $issues 'attachment_exception_template' 'warning' $rowNumber 'replacement_path' 'replacement_path_required' 'replacement_path is required when decision is recover.' }
        elseif ($decision -eq 'exception' -and (Test-Blank $row.exception_reason)) { Add-Issue $issues 'attachment_exception_template' 'warning' $rowNumber 'exception_reason' 'exception_reason_required' 'exception_reason is required when decision is exception.' }
        if (Test-Blank $row.approved_by) { Add-Issue $issues 'attachment_exception_template' 'warning' $rowNumber 'approved_by' 'approval_required' 'approved_by is required for audit trail.' }
    }
}

$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$issues = New-Object System.Collections.Generic.List[object]
if (-not (Test-Path -LiteralPath $UnitUserCsvPath -PathType Leaf)) { Add-Issue $issues 'unit_user_mapping_template' 'blocker' 0 'file' 'file_missing' 'Unit/user mapping template CSV is missing.' }
if (-not (Test-Path -LiteralPath $ProjectCsvPath -PathType Leaf)) { Add-Issue $issues 'project_mapping_template' 'blocker' 0 'file' 'file_missing' 'Project mapping template CSV is missing.' }
if (-not (Test-Path -LiteralPath $AttachmentExceptionCsvPath -PathType Leaf)) { Add-Issue $issues 'attachment_exception_template' 'blocker' 0 'file' 'file_missing' 'Attachment exception template CSV is missing.' }

Test-UnitRows $unitRows $issues
Test-ProjectRows $projectRows $issues
Test-AttachmentRows $attachmentRows $issues

$blockers = @($issues | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues | Where-Object { $_.severity -eq 'warning' }).Count

$byTemplate = @()
foreach ($template in @('unit_user_mapping_template', 'project_mapping_template', 'attachment_exception_template')) {
    $templateIssues = @($issues | Where-Object { $_.template -eq $template })
    $byTemplate += [ordered]@{
        template = $template
        blockers = @($templateIssues | Where-Object { $_.severity -eq 'blocker' }).Count
        warnings = @($templateIssues | Where-Object { $_.severity -eq 'warning' }).Count
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        blockers = $blockers
        warnings = $warnings
        unit_user_rows = @($unitRows).Count
        project_rows = @($projectRows).Count
        attachment_exception_rows = @($attachmentRows).Count
    }
    by_template = @($byTemplate)
    sample_issues = @($issues.ToArray() | Select-Object -First $SampleSize)
}

$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution validation written to $ReportPath"
