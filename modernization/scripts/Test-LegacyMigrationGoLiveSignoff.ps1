param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $rowNumber, $roleKey, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        role_key = $roleKey
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'signed', 'accepted_with_risk', 'rejected')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.role_key 'status' 'invalid_status' 'status must be pending, signed, accepted_with_risk, or rejected.'
        continue
    }

    if ($status -in @('signed', 'accepted_with_risk', 'rejected')) {
        if (Test-Blank $row.owner) { Add-Issue $issues 'warning' $rowNumber $row.role_key 'owner' 'owner_required' 'owner is required once a role signs off.' }
        if (Test-Blank $row.signed_by) { Add-Issue $issues 'warning' $rowNumber $row.role_key 'signed_by' 'signed_by_required' 'signed_by is required once a role signs off.' }
        if (Test-Blank $row.signed_at) { Add-Issue $issues 'warning' $rowNumber $row.role_key 'signed_at' 'signed_at_required' 'signed_at is required once a role signs off.' }
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'warning' $rowNumber $row.role_key 'notes' 'risk_notes_required' 'notes are required when accepting go-live with residual risk.'
    }

    if (($status -eq 'rejected') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.role_key 'notes' 'rejection_notes_required' 'notes are required when go-live signoff is rejected.'
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
    note = 'This report validates manual go-live signoff fields. It does not copy files, import records, switch traffic, update templates, or write database records.'
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
Write-Host "Legacy migration go-live signoff validation written to $ReportPath"
