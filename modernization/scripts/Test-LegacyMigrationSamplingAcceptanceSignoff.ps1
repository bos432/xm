param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-sampling-acceptance-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $sampleKey, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        sample_key = $sampleKey
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'pass', 'accepted_with_risk', 'fail', 'blocked')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.sample_key 'status' 'invalid_status' 'status must be pending, pass, accepted_with_risk, fail, or blocked.'
        continue
    }

    if ($status -in @('pass', 'accepted_with_risk', 'fail', 'blocked')) {
        if (Test-Blank $row.sampled_by) { Add-Issue $issues 'warning' $rowNumber $row.sample_key 'sampled_by' 'sampled_by_required' 'sampled_by is required once a sample is reviewed.' }
        if (Test-Blank $row.sampled_at) { Add-Issue $issues 'warning' $rowNumber $row.sample_key 'sampled_at' 'sampled_at_required' 'sampled_at is required once a sample is reviewed.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber $row.sample_key 'evidence_ref' 'evidence_ref_required' 'evidence_ref is required once a sample is reviewed.' }
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'warning' $rowNumber $row.sample_key 'notes' 'risk_notes_required' 'notes are required when accepting a sample with residual risk.'
    }

    if (($status -eq 'fail') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.sample_key 'notes' 'failure_notes_required' 'notes are required when a sample fails acceptance.'
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.sample_key 'notes' 'blocked_notes_required' 'notes are required when a sample is blocked.'
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$statusCounts = [ordered]@{}
foreach ($status in $validStatuses) { $statusCounts[$status] = 0 }
foreach ($row in @($rows)) {
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }
    if (-not $statusCounts.Contains($status)) { $statusCounts[$status] = 0 }
    $statusCounts[$status]++
}

$categoryCounts = [ordered]@{}
foreach ($row in @($rows)) {
    if (-not $categoryCounts.Contains($row.category)) { $categoryCounts[$row.category] = 0 }
    $categoryCounts[$row.category]++
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates manual business sampling acceptance fields. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        sample_rows = $rows.Count
        blockers = $blockers
        warnings = $warnings
        status_counts = $statusCounts
        category_counts = $categoryCounts
    }
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration sampling acceptance signoff validation written to $ReportPath"
