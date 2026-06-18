param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions-validation.json"),
    [string]$NextActionsPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.md"),
    [string]$BlockerCsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.blockers.csv"),
    [string]$BlockerMarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.blockers.md")
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

function Get-PropertyValue($object, $name) {
    if ($null -eq $object) { return $null }
    if ($object.PSObject.Properties.Name -notcontains $name) { return $null }
    return $object.$name
}

function Add-CountCheck($issues, $field, $actual, $expected, [ref]$mismatchCount) {
    if ([int64]$actual -ne [int64]$expected) {
        $mismatchCount.Value++
        Add-Issue $issues 'blocker' $field 'summary_mismatch' "$field ($actual) does not match calculated value ($expected)."
    }
}

function Get-ExpectedPriority($severity) {
    if ($severity -eq 'blocker') { return 1 }
    if ($severity -eq 'warning') { return 2 }
    return 3
}

function Test-Breakdown($issues, $items, $breakdown, $fieldName, [ref]$mismatchCount) {
    $groups = @($items | Group-Object $fieldName)
    $expected = @{}
    foreach ($group in $groups) {
        $expected[$group.Name] = [pscustomobject]@{
            count = $group.Count
            blockers = @($group.Group | Where-Object { $_.severity -eq 'blocker' }).Count
            warnings = @($group.Group | Where-Object { $_.severity -eq 'warning' }).Count
        }
    }

    foreach ($entry in @($breakdown)) {
        $name = [string](Get-PropertyValue $entry $fieldName)
        if (-not $expected.ContainsKey($name)) {
            $mismatchCount.Value++
            Add-Issue $issues 'blocker' "${fieldName}_breakdown" 'unexpected_breakdown_entry' "$fieldName breakdown contains an unexpected entry: $name."
            continue
        }

        $calculated = $expected[$name]
        foreach ($field in @('count', 'blockers', 'warnings')) {
            if ([int64]$entry.$field -ne [int64]$calculated.$field) {
                $mismatchCount.Value++
                Add-Issue $issues 'blocker' "${fieldName}_breakdown.$name.$field" 'breakdown_mismatch' "$fieldName breakdown for $name has $field=$($entry.$field), expected $($calculated.$field)."
            }
        }

        $expected.Remove($name)
    }

    foreach ($missingName in $expected.Keys) {
        $mismatchCount.Value++
        Add-Issue $issues 'blocker' "${fieldName}_breakdown" 'missing_breakdown_entry' "$fieldName breakdown is missing entry: $missingName."
    }
}

$report = Read-JsonReport $NextActionsPath
$issues = New-Object System.Collections.Generic.List[object]
$actionCount = 0
$blockerCount = 0
$warningCount = 0
$infoCount = 0
$topActionCount = 0
$csvRows = @()
$missingFiles = 0
$summaryMismatches = 0
$breakdownMismatches = 0
$missingRequiredFields = 0
$invalidSeverityCount = 0
$invalidStatusCount = 0
$priorityMismatches = 0
$csvCountMismatches = 0
$expectedOverallStatus = 'missing'

if (-not $report) {
    Add-Issue $issues 'blocker' $NextActionsPath 'missing_next_actions' 'next actions report is missing.'
} else {
    if (-not (Test-Blank $report.files.csv)) { $CsvPath = $report.files.csv }
    if (-not (Test-Blank $report.files.markdown)) { $MarkdownPath = $report.files.markdown }
    if (-not (Test-Blank $report.files.blocker_csv)) { $BlockerCsvPath = $report.files.blocker_csv }
    if (-not (Test-Blank $report.files.blocker_markdown)) { $BlockerMarkdownPath = $report.files.blocker_markdown }

    foreach ($fileCheck in @(
        @{ field = 'files.csv'; path = $CsvPath },
        @{ field = 'files.markdown'; path = $MarkdownPath },
        @{ field = 'files.blocker_csv'; path = $BlockerCsvPath },
        @{ field = 'files.blocker_markdown'; path = $BlockerMarkdownPath }
    )) {
        if (Test-Blank $fileCheck.path -or -not (Test-Path -LiteralPath $fileCheck.path -PathType Leaf)) {
            $missingFiles++
            Add-Issue $issues 'blocker' $fileCheck.field 'missing_output_file' "next actions output file is missing: $($fileCheck.path)"
        }
    }

    if (-not (Test-Path -LiteralPath $NextActionsPath -PathType Leaf)) {
        $missingFiles++
        Add-Issue $issues 'blocker' 'files.json' 'missing_output_file' "next actions JSON file is missing: $NextActionsPath"
    }

    $actions = @($report.actions)
    $blockerActions = @($report.blocker_actions)
    $actionCount = $actions.Count
    $blockerCount = @($actions | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($actions | Where-Object { $_.severity -eq 'warning' }).Count
    $infoCount = @($actions | Where-Object { $_.severity -eq 'info' }).Count
    $topActionCount = @($report.top_actions).Count
    $expectedOverallStatus = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }

    Add-CountCheck $issues 'summary.total_actions' $report.summary.total_actions $actionCount ([ref]$summaryMismatches)
    Add-CountCheck $issues 'summary.blockers' $report.summary.blockers $blockerCount ([ref]$summaryMismatches)
    Add-CountCheck $issues 'summary.warnings' $report.summary.warnings $warningCount ([ref]$summaryMismatches)
    Add-CountCheck $issues 'summary.info' $report.summary.info $infoCount ([ref]$summaryMismatches)
    Add-CountCheck $issues 'summary.top_actions' $report.summary.top_actions $topActionCount ([ref]$summaryMismatches)

    if ($report.overall_status -ne $expectedOverallStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "overall_status ($($report.overall_status)) does not match calculated value ($expectedOverallStatus)."
    }

    foreach ($item in $actions) {
        foreach ($field in @('priority', 'category', 'severity', 'status', 'title', 'owner', 'source', 'evidence', 'action', 'acceptance')) {
            if (Test-Blank $item.$field) {
                $missingRequiredFields++
                Add-Issue $issues 'blocker' "actions.$field" "blank_$field" "next action item has a blank $field."
            }
        }

        if (@('blocker', 'warning', 'info') -notcontains $item.severity) {
            $invalidSeverityCount++
            Add-Issue $issues 'blocker' "actions.$($item.category).severity" 'invalid_severity' "next action item has invalid severity: $($item.severity)."
        }

        if (@('blocked', 'not_ready', 'open', 'pending', 'ready') -notcontains $item.status) {
            $invalidStatusCount++
            Add-Issue $issues 'warning' "actions.$($item.category).status" 'unexpected_status' "next action item has unexpected status: $($item.status)."
        }

        $expectedPriority = Get-ExpectedPriority $item.severity
        if ([int]$item.priority -ne $expectedPriority) {
            $priorityMismatches++
            Add-Issue $issues 'warning' "actions.$($item.category).priority" 'priority_mismatch' "next action priority ($($item.priority)) does not match severity $($item.severity) expected priority ($expectedPriority)."
        }
    }

    Test-Breakdown $issues $actions @($report.owner_breakdown) 'owner' ([ref]$breakdownMismatches)
    Test-Breakdown $issues $actions @($report.category_breakdown) 'category' ([ref]$breakdownMismatches)

    if ($blockerActions.Count -ne $blockerCount) {
        $breakdownMismatches++
        Add-Issue $issues 'blocker' 'blocker_actions' 'blocker_action_count_mismatch' "blocker_actions count ($($blockerActions.Count)) does not match calculated blocker count ($blockerCount)."
    }

    foreach ($item in $blockerActions) {
        if ($item.severity -ne 'blocker') {
            $breakdownMismatches++
            Add-Issue $issues 'blocker' 'blocker_actions.severity' 'non_blocker_in_blocker_actions' "blocker_actions contains a non-blocker item: $($item.title)."
        }
    }

    Test-Breakdown $issues $blockerActions @($report.blocker_owner_breakdown | ForEach-Object {
        [pscustomobject][ordered]@{
            owner = $_.owner
            count = $_.blockers
            blockers = $_.blockers
            warnings = 0
        }
    }) 'owner' ([ref]$breakdownMismatches)
    Test-Breakdown $issues $blockerActions @($report.blocker_category_breakdown | ForEach-Object {
        [pscustomobject][ordered]@{
            category = $_.category
            count = $_.blockers
            blockers = $_.blockers
            warnings = 0
        }
    }) 'category' ([ref]$breakdownMismatches)

    if (-not (Test-Blank $CsvPath) -and (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        $csvRows = @(Import-Csv -LiteralPath $CsvPath -Encoding UTF8)
        if ($csvRows.Count -ne $topActionCount) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' 'files.csv' 'csv_row_count_mismatch' "CSV row count ($($csvRows.Count)) does not match top action count ($topActionCount)."
        }
    }

    $blockerCsvRows = @()
    if (-not (Test-Blank $BlockerCsvPath) -and (Test-Path -LiteralPath $BlockerCsvPath -PathType Leaf)) {
        $blockerCsvRows = @(Import-Csv -LiteralPath $BlockerCsvPath -Encoding UTF8)
        if ($blockerCsvRows.Count -ne $blockerCount) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' 'files.blocker_csv' 'blocker_csv_row_count_mismatch' "Blocker CSV row count ($($blockerCsvRows.Count)) does not match blocker count ($blockerCount)."
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$validation = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the next actions JSON, CSV, Markdown output, summary counts, breakdown counts, and required action fields. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $report) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        actions = $actionCount
        blockers_in_report = $blockerCount
        warnings_in_report = $warningCount
        info_in_report = $infoCount
        top_actions = $topActionCount
        expected_overall_status = $expectedOverallStatus
        missing_files = $missingFiles
        summary_mismatches = $summaryMismatches
        breakdown_mismatches = $breakdownMismatches
        missing_required_fields = $missingRequiredFields
        invalid_severities = $invalidSeverityCount
        invalid_statuses = $invalidStatusCount
        priority_mismatches = $priorityMismatches
        csv_rows = @($csvRows).Count
        csv_count_mismatches = $csvCountMismatches
        blockers = $blockers
        warnings = $warnings
    }
    next_actions = $NextActionsPath
    csv = $CsvPath
    markdown = $MarkdownPath
    issues = @($issues.ToArray())
}

$validation | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions validation written to $ReportPath"
