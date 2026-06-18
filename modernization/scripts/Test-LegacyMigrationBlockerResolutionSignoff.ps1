param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $stage, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        stage = $stage
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'approved', 'executed', 'verified', 'blocked')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.stage 'status' 'invalid_status' 'status must be pending, approved, executed, verified, or blocked.'
        continue
    }

    if ($status -in @('approved', 'executed', 'verified')) {
        if (Test-Blank $row.approved_by) { Add-Issue $issues 'warning' $rowNumber $row.stage 'approved_by' 'approved_by_required' 'approved_by is required once a blocker resolution is approved.' }
        if (Test-Blank $row.approved_at) { Add-Issue $issues 'warning' $rowNumber $row.stage 'approved_at' 'approved_at_required' 'approved_at is required once a blocker resolution is approved.' }
    }

    if ($status -in @('executed', 'verified')) {
        if (Test-Blank $row.executed_by) { Add-Issue $issues 'warning' $rowNumber $row.stage 'executed_by' 'executed_by is required once a blocker resolution is executed.' }
        if (Test-Blank $row.executed_at) { Add-Issue $issues 'warning' $rowNumber $row.stage 'executed_at' 'executed_at is required once a blocker resolution is executed.' }
    }

    if ($status -eq 'verified') {
        if (Test-Blank $row.verified_by) { Add-Issue $issues 'warning' $rowNumber $row.stage 'verified_by' 'verified_by_required' 'verified_by is required once a blocker resolution is verified.' }
        if (Test-Blank $row.verified_at) { Add-Issue $issues 'warning' $rowNumber $row.stage 'verified_at' 'verified_at_required' 'verified_at is required once a blocker resolution is verified.' }
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.stage 'notes' 'blocked_notes_required' 'notes are required when status is blocked.'
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
    note = 'This report validates manual blocker resolution signoff fields. It does not copy files, import records, update templates, or write database records.'
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
Write-Host "Legacy migration blocker resolution signoff validation written to $ReportPath"
