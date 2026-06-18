param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $owner, $template, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        owner = $owner
        template = $template
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'sent', 'accepted', 'completed', 'blocked')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.template 'status' 'invalid_status' 'status must be pending, sent, accepted, completed, or blocked.'
        continue
    }

    if ($status -in @('sent', 'accepted', 'completed')) {
        if (Test-Blank $row.recipient) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'recipient' 'recipient_required' 'recipient is required once a file is sent.' }
        if (Test-Blank $row.sent_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'sent_at' 'sent_at_required' 'sent_at is required once a file is sent.' }
    }

    if ($status -in @('accepted', 'completed')) {
        if (Test-Blank $row.accepted_by) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'accepted_by' 'accepted_by_required' 'accepted_by is required once a file is accepted.' }
        if (Test-Blank $row.accepted_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'accepted_at' 'accepted_at_required' 'accepted_at is required once a file is accepted.' }
    }

    if ($status -eq 'completed') {
        if (Test-Blank $row.completed_by) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'completed_by' 'completed_by_required' 'completed_by is required once a file is completed.' }
        if (Test-Blank $row.completed_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.template 'completed_at' 'completed_at_required' 'completed_at is required once a file is completed.' }
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.template 'notes' 'blocked_notes_required' 'notes are required when status is blocked.'
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
    note = 'This report validates manual distribution signoff fields. It does not edit templates, copy files, import records, or write database records.'
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
Write-Host "Legacy migration resolution distribution signoff validation written to $ReportPath"
