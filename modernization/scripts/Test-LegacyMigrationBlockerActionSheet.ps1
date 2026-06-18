param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-action-sheet-validation.json"),
    [string]$ActionSheetPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-action-sheet.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        field = $field
        code = $code
        message = $message
    })
}

$sheet = Read-JsonReport $ActionSheetPath
$issues = New-Object System.Collections.Generic.List[object]
$itemCount = 0
$blockerCount = 0
$warningCount = 0
$affectedRecords = 0
$duplicateKeyCount = 0
$invalidSeverityCount = 0
$missingRequiredFields = 0
$summaryMismatches = 0
$missingSourceReports = 0
$expectedOverallStatus = 'missing'

if (-not $sheet) {
    Add-Issue $issues 'blocker' $ActionSheetPath 'missing_action_sheet' 'blocker action sheet is missing.'
} else {
    $items = @($sheet.items)
    $itemCount = $items.Count
    $blockerCount = @($items | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($items | Where-Object { $_.severity -eq 'warning' }).Count
    $affectedRecords = [int64](@($items | ForEach-Object { [int64]$_.affected_count } | Measure-Object -Sum).Sum)
    $expectedOverallStatus = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }

    $summaryChecks = @(
        @{ field = 'summary.total_items'; actual = $sheet.summary.total_items; expected = $itemCount },
        @{ field = 'summary.blockers'; actual = $sheet.summary.blockers; expected = $blockerCount },
        @{ field = 'summary.warnings'; actual = $sheet.summary.warnings; expected = $warningCount },
        @{ field = 'summary.affected_records'; actual = $sheet.summary.affected_records; expected = $affectedRecords }
    )
    foreach ($check in $summaryChecks) {
        if ([int64]$check.actual -ne [int64]$check.expected) {
            $summaryMismatches++
            Add-Issue $issues 'blocker' $check.field 'summary_mismatch' "$($check.field) ($($check.actual)) does not match calculated value ($($check.expected))."
        }
    }

    if ($sheet.overall_status -ne $expectedOverallStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "overall_status ($($sheet.overall_status)) does not match calculated value ($expectedOverallStatus)."
    }

    foreach ($propertyName in @('record_import_plan', 'unit_user_id_map', 'project_id_map', 'attachment_quality', 'attachment_import_dry_run', 'project_file_db_dry_run')) {
        if (-not [bool]$sheet.source_reports.$propertyName) {
            $missingSourceReports++
            Add-Issue $issues 'blocker' "source_reports.$propertyName" 'missing_source_report' "required source report is not available: $propertyName."
        }
    }

    foreach ($group in @($items | Group-Object key | Where-Object { $_.Count -gt 1 })) {
        $duplicateKeyCount++
        Add-Issue $issues 'blocker' 'items.key' 'duplicate_action_key' "action key appears more than once: $($group.Name)."
    }

    foreach ($item in $items) {
        foreach ($field in @('key', 'severity', 'owner', 'title', 'source', 'action', 'acceptance')) {
            if (Test-Blank $item.$field) {
                $missingRequiredFields++
                Add-Issue $issues 'blocker' "items.$field" "blank_$field" "action sheet item has a blank $field."
            }
        }

        if (@('blocker', 'warning') -notcontains $item.severity) {
            $invalidSeverityCount++
            Add-Issue $issues 'blocker' "items.$($item.key).severity" 'invalid_severity' "action sheet item $($item.key) has invalid severity: $($item.severity)."
        }

        if ([int64]$item.affected_count -lt 0) {
            Add-Issue $issues 'blocker' "items.$($item.key).affected_count" 'negative_affected_count' "action sheet item $($item.key) has negative affected_count."
        }

        if ([int64]$item.affected_count -gt 0 -and @($item.samples).Count -eq 0 -and $item.key -ne 'attachment_execute_required') {
            Add-Issue $issues 'warning' "items.$($item.key).samples" 'missing_samples' "action sheet item $($item.key) has affected records but no samples."
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates blocker action sheet structure, summary counts, required fields, and source report availability. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $sheet) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        items = $itemCount
        blockers_in_sheet = $blockerCount
        warnings_in_sheet = $warningCount
        affected_records = $affectedRecords
        expected_overall_status = $expectedOverallStatus
        duplicate_keys = $duplicateKeyCount
        invalid_severities = $invalidSeverityCount
        missing_required_fields = $missingRequiredFields
        missing_source_reports = $missingSourceReports
        summary_mismatches = $summaryMismatches
        blockers = $blockers
        warnings = $warnings
    }
    action_sheet = $ActionSheetPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker action sheet validation written to $ReportPath"
