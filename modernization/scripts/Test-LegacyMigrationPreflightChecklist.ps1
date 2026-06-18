param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-checklist-validation.json"),
    [string]$PreflightPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-checklist.json")
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

$preflight = Read-JsonReport $PreflightPath
$issues = New-Object System.Collections.Generic.List[object]
$itemCount = 0
$blockerCount = 0
$warningCount = 0
$infoCount = 0
$doneCount = 0
$duplicateItemCount = 0
$invalidSeverityCount = 0
$invalidStatusCount = 0
$summaryMismatches = 0
$expectedOverallStatus = 'missing'

if (-not $preflight) {
    Add-Issue $issues 'blocker' $PreflightPath 'missing_preflight_checklist' 'preflight checklist report is missing.'
} else {
    $items = @($preflight.items)
    $itemCount = $items.Count
    $blockerCount = @($items | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($items | Where-Object { $_.severity -eq 'warning' }).Count
    $infoCount = @($items | Where-Object { $_.severity -eq 'info' }).Count
    $doneCount = @($items | Where-Object { $_.status -eq 'done' }).Count
    $expectedOverallStatus = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }

    $summaryChecks = @(
        @{ field = 'summary.total_items'; actual = $preflight.summary.total_items; expected = $itemCount },
        @{ field = 'summary.blockers'; actual = $preflight.summary.blockers; expected = $blockerCount },
        @{ field = 'summary.warnings'; actual = $preflight.summary.warnings; expected = $warningCount },
        @{ field = 'summary.info'; actual = $preflight.summary.info; expected = $infoCount },
        @{ field = 'summary.done'; actual = $preflight.summary.done; expected = $doneCount }
    )

    foreach ($check in $summaryChecks) {
        if ([int]$check.actual -ne [int]$check.expected) {
            $summaryMismatches++
            Add-Issue $issues 'blocker' $check.field 'summary_mismatch' "$($check.field) ($($check.actual)) does not match calculated value ($($check.expected))."
        }
    }

    if ($preflight.overall_status -ne $expectedOverallStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "overall_status ($($preflight.overall_status)) does not match calculated value ($expectedOverallStatus)."
    }

    foreach ($group in @($items | ForEach-Object { "$($_.category)|$($_.title)|$($_.source)" } | Group-Object | Where-Object { $_.Count -gt 1 })) {
        $duplicateItemCount++
        Add-Issue $issues 'warning' 'items' 'duplicate_preflight_item' "preflight item appears more than once: $($group.Name)."
    }

    foreach ($item in $items) {
        foreach ($field in @('category', 'severity', 'title', 'source', 'status', 'action')) {
            if (Test-Blank $item.$field) {
                Add-Issue $issues 'warning' "items.$field" "blank_$field" "preflight item has a blank $field."
            }
        }

        if (@('blocker', 'warning', 'info') -notcontains $item.severity) {
            $invalidSeverityCount++
            Add-Issue $issues 'blocker' "items.$($item.title).severity" 'invalid_severity' "preflight item has invalid severity: $($item.severity)."
        }

        if (@('open', 'optional', 'done') -notcontains $item.status) {
            $invalidStatusCount++
            Add-Issue $issues 'blocker' "items.$($item.title).status" 'invalid_status' "preflight item has invalid status: $($item.status)."
        }

        if ($item.severity -eq 'blocker' -and $item.status -ne 'open') {
            Add-Issue $issues 'warning' "items.$($item.title).status" 'blocker_not_open' "blocker item should normally be open: $($item.title)."
        }
        if ($item.status -eq 'done' -and $item.severity -ne 'info') {
            Add-Issue $issues 'warning' "items.$($item.title).severity" 'done_not_info' "done item should normally be informational: $($item.title)."
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates preflight checklist structure, summary counts, item status values, and calculated readiness. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $preflight) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        items = $itemCount
        blockers_in_preflight = $blockerCount
        warnings_in_preflight = $warningCount
        info_in_preflight = $infoCount
        done_items = $doneCount
        expected_overall_status = $expectedOverallStatus
        duplicate_items = $duplicateItemCount
        invalid_severities = $invalidSeverityCount
        invalid_statuses = $invalidStatusCount
        summary_mismatches = $summaryMismatches
        blockers = $blockers
        warnings = $warnings
    }
    preflight_checklist = $PreflightPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration preflight checklist validation written to $ReportPath"
