param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Get-Field($row, $name, $default = '') {
    if ($null -eq $row) { return $default }
    if ($row.PSObject.Properties.Name -contains $name) { return $row.$name }
    return $default
}

function Add-Issue($issues, $severity, $rowNumber, $itemId, $relativePath, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        item_id = $itemId
        relative_path = $relativePath
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'mitigated', 'accepted_with_risk', 'blocked')
$requiredColumns = @('status', 'relative_path', 'severity', 'owner', 'evidence_ref', 'notes')

if ((Test-Path -LiteralPath $CsvPath -PathType Leaf) -and $rows.Count -gt 0) {
    $columnNames = @($rows[0].PSObject.Properties.Name)
    foreach ($column in $requiredColumns) {
        if ($columnNames -notcontains $column) {
            Add-Issue $issues 'blocker' 1 '' '' $column 'missing_column' "required CSV column '$column' is missing."
        }
    }
}

$rowNumber = 1
foreach ($row in @($rows)) {
    $rowNumber++
    $itemId = Get-Field $row 'item_id'
    $relativePath = Get-Field $row 'relative_path'
    $status = ([string](Get-Field $row 'status' 'pending')).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $itemId $relativePath 'status' 'invalid_status' 'status must be pending, mitigated, accepted_with_risk, or blocked.'
        continue
    }

    if ($status -eq 'pending') {
        Add-Issue $issues 'warning' $rowNumber $itemId $relativePath 'status' 'pending_review' 'file still needs mitigation, risk acceptance, or explicit blocked notes before go-live.'
        continue
    }

    if (Test-Blank (Get-Field $row 'owner')) {
        Add-Issue $issues 'warning' $rowNumber $itemId $relativePath 'owner' 'owner_required' 'owner is required once a public executable file is reviewed.'
    }

    if (Test-Blank (Get-Field $row 'evidence_ref')) {
        Add-Issue $issues 'warning' $rowNumber $itemId $relativePath 'evidence_ref' 'evidence_required' 'evidence_ref is required once a public executable file is reviewed.'
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank (Get-Field $row 'notes'))) {
        Add-Issue $issues 'warning' $rowNumber $itemId $relativePath 'notes' 'risk_notes_required' 'notes are required when accepting residual public executable risk.'
    }

    if (($status -eq 'blocked') -and (Test-Blank (Get-Field $row 'notes'))) {
        Add-Issue $issues 'blocker' $rowNumber $itemId $relativePath 'notes' 'blocked_notes_required' 'notes are required when a public executable file remains blocked.'
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$statusCounts = [ordered]@{}
$severityCounts = [ordered]@{}
foreach ($status in $validStatuses) { $statusCounts[$status] = 0 }

foreach ($row in @($rows)) {
    $status = ([string](Get-Field $row 'status' 'pending')).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }
    if (-not $statusCounts.Contains($status)) { $statusCounts[$status] = 0 }
    $statusCounts[$status]++

    $rowSeverity = ([string](Get-Field $row 'severity' 'unknown')).Trim().ToLowerInvariant()
    if (Test-Blank $rowSeverity) { $rowSeverity = 'unknown' }
    if (-not $severityCounts.Contains($rowSeverity)) { $severityCounts[$rowSeverity] = 0 }
    $severityCounts[$rowSeverity]++
}

$reviewedFiles = $statusCounts['mitigated'] + $statusCounts['accepted_with_risk'] + $statusCounts['blocked']

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates manual public executable worklist fields. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        worklist_rows = $rows.Count
        reviewed_files = $reviewedFiles
        pending_files = $statusCounts['pending']
        mitigated_files = $statusCounts['mitigated']
        accepted_with_risk_files = $statusCounts['accepted_with_risk']
        blocked_files = $statusCounts['blocked']
        blockers = $blockers
        warnings = $warnings
        status_counts = $statusCounts
        severity_counts = $severityCounts
    }
    csv_path = $CsvPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable worklist validation written to $ReportPath"
