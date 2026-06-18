param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-gate-validation.json"),
    [string]$GatePath = (Join-Path $PSScriptRoot "legacy-migration-go-live-gate.json")
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

$gate = Read-JsonReport $GatePath
$issues = New-Object System.Collections.Generic.List[object]
$gateCount = 0
$passedCount = 0
$openCount = 0
$blockerCount = 0
$warningCount = 0
$csvCountMismatches = 0
$missingSourceFiles = 0
$duplicateKeyCount = 0
$invalidStatusCount = 0
$invalidSeverityCount = 0
$summaryMismatches = 0
$nextStepMismatches = 0
$writeCutoverMismatches = 0
$expectedOverallStatus = 'missing'
$csvPath = [System.IO.Path]::ChangeExtension($GatePath, '.csv')

if (-not $gate) {
    Add-Issue $issues 'blocker' $GatePath 'missing_go_live_gate' 'go-live gate report is missing.'
} else {
    $gates = @($gate.gates)
    $gateCount = $gates.Count
    $passedCount = @($gates | Where-Object { $_.status -eq 'pass' }).Count
    $openCount = @($gates | Where-Object { $_.status -eq 'open' }).Count
    $blockerCount = @($gates | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($gates | Where-Object { $_.severity -eq 'warning' }).Count
    $expectedCompletion = if ($gateCount -eq 0) { 0 } else { [math]::Round(($passedCount / $gateCount) * 100, 2) }
    $expectedOverallStatus = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }
    $expectedWriteCutoverReady = ($blockerCount -eq 0 -and $warningCount -eq 0)

    $summaryChecks = @(
        @{ field = 'summary.total_gates'; actual = $gate.summary.total_gates; expected = $gateCount },
        @{ field = 'summary.passed_gates'; actual = $gate.summary.passed_gates; expected = $passedCount },
        @{ field = 'summary.open_gates'; actual = $gate.summary.open_gates; expected = $openCount },
        @{ field = 'summary.blockers'; actual = $gate.summary.blockers; expected = $blockerCount },
        @{ field = 'summary.warnings'; actual = $gate.summary.warnings; expected = $warningCount },
        @{ field = 'summary.completion_percent'; actual = $gate.summary.completion_percent; expected = $expectedCompletion }
    )

    foreach ($check in $summaryChecks) {
        if ([decimal]$check.actual -ne [decimal]$check.expected) {
            $summaryMismatches++
            Add-Issue $issues 'blocker' $check.field 'summary_mismatch' "$($check.field) ($($check.actual)) does not match calculated value ($($check.expected))."
        }
    }

    if ($gate.overall_status -ne $expectedOverallStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "overall_status ($($gate.overall_status)) does not match calculated value ($expectedOverallStatus)."
    }

    if ([bool]$gate.write_cutover_ready -ne [bool]$expectedWriteCutoverReady) {
        $writeCutoverMismatches++
        Add-Issue $issues 'blocker' 'write_cutover_ready' 'write_cutover_ready_mismatch' "write_cutover_ready ($($gate.write_cutover_ready)) does not match calculated value ($expectedWriteCutoverReady)."
    }

    $expectedNextStep = @($gates | Where-Object { $_.status -ne 'pass' } | Select-Object -First 1)
    $actualNextStep = @($gate.next_step | Select-Object -First 1)
    $expectedNextKey = if ($expectedNextStep.Count -gt 0) { $expectedNextStep[0].key } else { $null }
    $actualNextKey = if ($actualNextStep.Count -gt 0) { $actualNextStep[0].key } else { $null }
    if ($expectedNextKey -ne $actualNextKey) {
        $nextStepMismatches++
        Add-Issue $issues 'blocker' 'next_step' 'next_step_mismatch' "next_step key ($actualNextKey) does not match first non-pass gate ($expectedNextKey)."
    }

    if (Test-Path -LiteralPath $csvPath -PathType Leaf) {
        $csvRows = Read-CsvRows $csvPath
        if ($csvRows.Count -ne $gateCount) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' $csvPath 'csv_count_mismatch' "go-live gate CSV row count ($($csvRows.Count)) does not match gates count ($gateCount)."
        }
    } else {
        Add-Issue $issues 'blocker' $csvPath 'missing_csv' 'go-live gate CSV report is missing.'
    }

    foreach ($group in @($gates | Group-Object key | Where-Object { $_.Count -gt 1 })) {
        $duplicateKeyCount++
        Add-Issue $issues 'blocker' 'gates.key' 'duplicate_gate_key' "gate key is duplicated: $($group.Name)."
    }

    foreach ($item in $gates) {
        if (Test-Blank $item.key) {
            Add-Issue $issues 'blocker' 'gates.key' 'blank_gate_key' 'gate has a blank key.'
        }
        if (@('pass', 'open', 'blocked', 'missing') -notcontains $item.status) {
            $invalidStatusCount++
            Add-Issue $issues 'blocker' "gates.$($item.key).status" 'invalid_gate_status' "gate $($item.key) has invalid status $($item.status)."
        }
        if (@('info', 'warning', 'blocker') -notcontains $item.severity) {
            $invalidSeverityCount++
            Add-Issue $issues 'blocker' "gates.$($item.key).severity" 'invalid_gate_severity' "gate $($item.key) has invalid severity $($item.severity)."
        }
        if ($item.status -eq 'pass' -and $item.severity -ne 'info') {
            Add-Issue $issues 'warning' "gates.$($item.key).severity" 'pass_gate_not_info' "pass gate $($item.key) has severity $($item.severity), expected info."
        }
        if (($item.status -eq 'blocked' -or $item.status -eq 'missing') -and $item.severity -ne 'blocker') {
            Add-Issue $issues 'warning' "gates.$($item.key).severity" 'blocked_gate_not_blocker' "blocked or missing gate $($item.key) has severity $($item.severity), expected blocker."
        }
        if ($item.status -eq 'open' -and $item.severity -ne 'warning') {
            Add-Issue $issues 'warning' "gates.$($item.key).severity" 'open_gate_not_warning' "open gate $($item.key) has severity $($item.severity), expected warning."
        }
        if (Test-Blank $item.source) {
            Add-Issue $issues 'warning' "gates.$($item.key).source" 'blank_source' "gate $($item.key) has a blank source path."
        } elseif (-not (Test-Path -LiteralPath $item.source)) {
            $missingSourceFiles++
            Add-Issue $issues 'blocker' "gates.$($item.key).source" 'missing_source_file' "gate source file is missing for $($item.key): $($item.source)."
        }
        foreach ($field in @('title', 'evidence', 'action', 'acceptance')) {
            if (Test-Blank $item.$field) {
                Add-Issue $issues 'warning' "gates.$($item.key).$field" "blank_$field" "gate $($item.key) has a blank $field."
            }
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates go-live gate structure, calculated summary fields, CSV row count, source file references, and write cutover readiness. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $gate) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        gates = $gateCount
        passed_gates = $passedCount
        open_gates = $openCount
        blockers_in_gate = $blockerCount
        warnings_in_gate = $warningCount
        expected_overall_status = $expectedOverallStatus
        duplicate_keys = $duplicateKeyCount
        invalid_statuses = $invalidStatusCount
        invalid_severities = $invalidSeverityCount
        missing_source_files = $missingSourceFiles
        csv_count_mismatches = $csvCountMismatches
        summary_mismatches = $summaryMismatches
        next_step_mismatches = $nextStepMismatches
        write_cutover_mismatches = $writeCutoverMismatches
        blockers = $blockers
        warnings = $warnings
    }
    go_live_gate = $GatePath
    go_live_gate_csv = $csvPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live gate validation written to $ReportPath"
