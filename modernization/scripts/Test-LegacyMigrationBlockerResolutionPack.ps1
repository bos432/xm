param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack-validation.json"),
    [string]$ResolutionPackPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.json")
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

$pack = Read-JsonReport $ResolutionPackPath
$issues = New-Object System.Collections.Generic.List[object]
$itemCount = 0
$blockedStageCount = 0
$csvCountMismatches = 0
$missingFiles = 0
$missingSourceReports = 0
$duplicateStageCount = 0
$invalidStatusCount = 0
$invalidSeverityCount = 0
$missingRequiredFields = 0
$summaryMismatches = 0
$expectedOverallStatus = 'missing'
$csvPath = $null
$markdownPath = $null

if (-not $pack) {
    Add-Issue $issues 'blocker' $ResolutionPackPath 'missing_resolution_pack' 'blocker resolution pack is missing.'
} else {
    $items = @($pack.items)
    $itemCount = $items.Count
    $blockedStageCount = @($items | Where-Object { $_.severity -eq 'blocker' }).Count
    $expectedOverallStatus = if ($blockedStageCount -gt 0) { 'blocked' } else { 'ready' }
    $csvPath = $pack.files.csv
    $markdownPath = $pack.files.markdown

    foreach ($pathInfo in @(
        @{ field = 'files.csv'; path = $csvPath },
        @{ field = 'files.markdown'; path = $markdownPath }
    )) {
        if (Test-Blank $pathInfo.path) {
            $missingFiles++
            Add-Issue $issues 'blocker' $pathInfo.field 'blank_output_path' "$($pathInfo.field) is blank."
        } elseif (-not (Test-Path -LiteralPath $pathInfo.path -PathType Leaf)) {
            $missingFiles++
            Add-Issue $issues 'blocker' $pathInfo.field 'missing_output_file' "$($pathInfo.field) file is missing: $($pathInfo.path)."
        }
    }

    if (-not (Test-Blank $csvPath) -and (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
        $csvRows = Read-CsvRows $csvPath
        if ($csvRows.Count -ne $itemCount) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' 'files.csv' 'csv_count_mismatch' "CSV row count ($($csvRows.Count)) does not match item count ($itemCount)."
        }
    }

    $summaryChecks = @(
        @{ field = 'summary.total_items'; actual = $pack.summary.total_items; expected = $itemCount },
        @{ field = 'summary.blocked_stages'; actual = $pack.summary.blocked_stages; expected = $blockedStageCount }
    )
    foreach ($check in $summaryChecks) {
        if ([int]$check.actual -ne [int]$check.expected) {
            $summaryMismatches++
            Add-Issue $issues 'blocker' $check.field 'summary_mismatch' "$($check.field) ($($check.actual)) does not match calculated value ($($check.expected))."
        }
    }

    if ([bool]$pack.summary.csv_exists -ne (-not (Test-Blank $csvPath) -and (Test-Path -LiteralPath $csvPath -PathType Leaf))) {
        $summaryMismatches++
        Add-Issue $issues 'blocker' 'summary.csv_exists' 'summary_mismatch' 'summary.csv_exists does not match CSV file existence.'
    }
    if ([bool]$pack.summary.markdown_exists -ne (-not (Test-Blank $markdownPath) -and (Test-Path -LiteralPath $markdownPath -PathType Leaf))) {
        $summaryMismatches++
        Add-Issue $issues 'blocker' 'summary.markdown_exists' 'summary_mismatch' 'summary.markdown_exists does not match Markdown file existence.'
    }
    if ($pack.overall_status -ne $expectedOverallStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "overall_status ($($pack.overall_status)) does not match calculated value ($expectedOverallStatus)."
    }

    foreach ($propertyName in @('batch_plan', 'blocker_action_sheet', 'preflight_checklist')) {
        if (-not [bool]$pack.source_reports.$propertyName) {
            $missingSourceReports++
            Add-Issue $issues 'blocker' "source_reports.$propertyName" 'missing_source_report' "source report is not available: $propertyName."
        }
    }

    foreach ($group in @($items | Group-Object stage | Where-Object { $_.Count -gt 1 })) {
        $duplicateStageCount++
        Add-Issue $issues 'blocker' 'items.stage' 'duplicate_stage' "stage appears more than once: $($group.Name)."
    }

    foreach ($item in $items) {
        foreach ($field in @('stage', 'status', 'severity', 'owner')) {
            if (Test-Blank $item.$field) {
                $missingRequiredFields++
                Add-Issue $issues 'blocker' "items.$field" "blank_$field" "resolution pack item has a blank $field."
            }
        }

        if (@('blocked', 'missing') -notcontains $item.status) {
            $invalidStatusCount++
            Add-Issue $issues 'blocker' "items.$($item.stage).status" 'invalid_status' "resolution pack stage $($item.stage) has invalid status: $($item.status)."
        }
        if ($item.severity -ne 'blocker') {
            $invalidSeverityCount++
            Add-Issue $issues 'blocker' "items.$($item.stage).severity" 'invalid_severity' "resolution pack stage $($item.stage) has invalid severity: $($item.severity)."
        }

        foreach ($arrayField in @('allowed_actions', 'forbidden_actions', 'validation_checks', 'manual_commands', 'preflight_titles')) {
            if (@($item.$arrayField).Count -eq 0) {
                $missingRequiredFields++
                Add-Issue $issues 'blocker' "items.$($item.stage).$arrayField" "missing_$arrayField" "resolution pack stage $($item.stage) has no $arrayField."
            }
        }

        foreach ($countField in @('planned_count', 'ready_count', 'waiting_count', 'blocked_count')) {
            if ([int64]$item.$countField -lt 0) {
                Add-Issue $issues 'blocker' "items.$($item.stage).$countField" 'negative_count' "resolution pack stage $($item.stage) has negative $countField."
            }
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates blocker resolution pack structure, output files, summary counts, and required operator guidance. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $pack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        items = $itemCount
        blocked_stages = $blockedStageCount
        expected_overall_status = $expectedOverallStatus
        missing_files = $missingFiles
        missing_source_reports = $missingSourceReports
        duplicate_stages = $duplicateStageCount
        invalid_statuses = $invalidStatusCount
        invalid_severities = $invalidSeverityCount
        missing_required_fields = $missingRequiredFields
        csv_count_mismatches = $csvCountMismatches
        summary_mismatches = $summaryMismatches
        blockers = $blockers
        warnings = $warnings
    }
    resolution_pack = $ResolutionPackPath
    resolution_pack_csv = $csvPath
    resolution_pack_markdown = $markdownPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker resolution pack validation written to $ReportPath"
