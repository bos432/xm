param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv"),
    [string]$HandoffPackPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$handoffPack = Read-JsonReport $HandoffPackPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'delivered', 'accepted', 'accepted_with_risk', 'blocked')

if (-not $handoffPack) {
    Add-Issue $issues 'blocker' 0 'handoff_pack' 'missing_handoff_pack' 'handoff pack report is missing.'
}

if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
    Add-Issue $issues 'blocker' 0 'csv' 'missing_signoff_csv' 'handoff signoff CSV is missing.'
}

if ($rows.Count -ne 1) {
    Add-Issue $issues 'blocker' 0 'csv' 'signoff_row_count_mismatch' "handoff signoff CSV should contain exactly one row, found $($rows.Count)."
}

$rowNumber = 1
foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber 'status' 'invalid_status' 'status must be pending, delivered, accepted, accepted_with_risk, or blocked.'
        continue
    }

    if (Test-Blank $row.owner) {
        Add-Issue $issues 'warning' $rowNumber 'owner' 'owner_required' 'owner is required for handoff signoff.'
    }

    if (Test-Blank $row.package_file -or -not (Test-Path -LiteralPath $row.package_file -PathType Leaf)) {
        Add-Issue $issues 'blocker' $rowNumber 'package_file' 'missing_package_file' 'handoff package ZIP must exist before signoff.'
    }

    if ([int]$row.missing_required -gt 0) {
        Add-Issue $issues 'blocker' $rowNumber 'missing_required' 'handoff_missing_required' 'handoff package still has missing required files.'
    }

    if ($status -in @('delivered', 'accepted', 'accepted_with_risk')) {
        if (Test-Blank $row.recipient) { Add-Issue $issues 'warning' $rowNumber 'recipient' 'recipient_required' 'recipient is required once the handoff package is delivered.' }
        if (Test-Blank $row.sent_at) { Add-Issue $issues 'warning' $rowNumber 'sent_at' 'sent_at_required' 'sent_at is required once the handoff package is delivered.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber 'evidence_ref' 'evidence_required' 'evidence_ref is required once the handoff package is delivered.' }
    }

    if ($status -in @('accepted', 'accepted_with_risk')) {
        if (Test-Blank $row.accepted_by) { Add-Issue $issues 'warning' $rowNumber 'accepted_by' 'accepted_by_required' 'accepted_by is required once the handoff package is accepted.' }
        if (Test-Blank $row.accepted_at) { Add-Issue $issues 'warning' $rowNumber 'accepted_at' 'accepted_at_required' 'accepted_at is required once the handoff package is accepted.' }
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'warning' $rowNumber 'notes' 'risk_notes_required' 'notes are required when accepting handoff package residual risk.'
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber 'notes' 'blocked_notes_required' 'notes are required when handoff package signoff is blocked.'
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
    note = 'This report validates manual handoff signoff fields for the public executable remediation wave signoff package. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
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
Write-Host "Legacy public executable remediation wave signoff handoff signoff validation written to $ReportPath"
