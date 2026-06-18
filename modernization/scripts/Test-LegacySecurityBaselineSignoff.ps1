param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-baseline-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-baseline-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $stepKey, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        step_key = $stepKey
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'mitigated', 'accepted_with_risk', 'blocked')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.step_key 'status' 'invalid_status' 'status must be pending, mitigated, accepted_with_risk, or blocked.'
        continue
    }

    if ($status -in @('mitigated', 'accepted_with_risk', 'blocked')) {
        if (Test-Blank $row.owner) { Add-Issue $issues 'warning' $rowNumber $row.step_key 'owner' 'owner_required' 'owner is required once a security item is reviewed.' }
        if (Test-Blank $row.resolved_by) { Add-Issue $issues 'warning' $rowNumber $row.step_key 'resolved_by' 'resolved_by_required' 'resolved_by is required once a security item is reviewed.' }
        if (Test-Blank $row.resolved_at) { Add-Issue $issues 'warning' $rowNumber $row.step_key 'resolved_at' 'resolved_at_required' 'resolved_at is required once a security item is reviewed.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber $row.step_key 'evidence_ref' 'evidence_required' 'evidence_ref is required once a security item is reviewed.' }
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'warning' $rowNumber $row.step_key 'notes' 'risk_notes_required' 'notes are required when accepting residual security risk.'
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.step_key 'notes' 'blocked_notes_required' 'notes are required when a security item remains blocked.'
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

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates manual security baseline signoff fields. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_rows = $rows.Count
        blockers = $blockers
        warnings = $warnings
        status_counts = $statusCounts
    }
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy security baseline signoff validation written to $ReportPath"