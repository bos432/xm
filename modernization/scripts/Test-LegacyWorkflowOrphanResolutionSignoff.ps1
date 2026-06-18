param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-workflow-orphan-resolution-signoff.csv")
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Test-PositiveInteger($value) {
    if (Test-Blank $value) { return $false }
    return [regex]::IsMatch([string]$value, '^[1-9][0-9]*$')
}

function Add-Issue($issues, $severity, $rowNumber, $legacyId, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        legacy_id = $legacyId
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validDecisions = @('pending', 'archive', 'link', 'exclude', 'blocked')
$rowNumber = 1

foreach ($row in @($rows)) {
    $rowNumber++
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()
    if (Test-Blank $decision) { $decision = 'pending' }

    if ($validDecisions -notcontains $decision) {
        Add-Issue $issues 'blocker' $rowNumber $row.legacy_id 'decision' 'invalid_decision' 'decision must be pending, archive, link, exclude, or blocked.'
        continue
    }

    if ($decision -in @('archive', 'link', 'exclude', 'blocked')) {
        if (Test-Blank $row.approved_by) { Add-Issue $issues 'warning' $rowNumber $row.legacy_id 'approved_by' 'approved_by_required' 'approved_by is required once an orphan workflow decision is made.' }
        if (Test-Blank $row.approved_at) { Add-Issue $issues 'warning' $rowNumber $row.legacy_id 'approved_at' 'approved_at_required' 'approved_at is required once an orphan workflow decision is made.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber $row.legacy_id 'evidence_ref' 'evidence_ref_required' 'evidence_ref is required once an orphan workflow decision is made.' }
    }

    if ($decision -eq 'link') {
        if (-not (Test-PositiveInteger $row.target_project_id)) { Add-Issue $issues 'blocker' $rowNumber $row.legacy_id 'target_project_id' 'target_project_id_required' 'target_project_id must be a positive integer when decision is link.' }
    }

    if ($decision -in @('archive', 'exclude', 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues $(if ($decision -eq 'blocked') { 'blocker' } else { 'warning' }) $rowNumber $row.legacy_id 'notes' 'notes_required' 'notes are required when decision is archive, exclude, or blocked.'
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$decisionCounts = [ordered]@{}
foreach ($decision in $validDecisions) { $decisionCounts[$decision] = 0 }
foreach ($row in @($rows)) {
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()
    if (Test-Blank $decision) { $decision = 'pending' }
    if (-not $decisionCounts.Contains($decision)) { $decisionCounts[$decision] = 0 }
    $decisionCounts[$decision]++
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates manual workflow orphan handling decisions. It does not import records, link records, exclude records, or write database records.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        orphan_rows = $rows.Count
        blockers = $blockers
        warnings = $warnings
        decision_counts = $decisionCounts
    }
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy workflow orphan resolution signoff validation written to $ReportPath"
