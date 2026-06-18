param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff.csv"),
    [string]$OwnerFilesPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.json")
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

function Add-Issue($issues, $severity, $rowNumber, $owner, $slug, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        owner = $owner
        slug = $slug
        field = $field
        code = $code
        message = $message
    })
}

function Get-SignoffKey($owner, $slug) {
    return (([string]$owner).Trim().ToLowerInvariant() + '|' + ([string]$slug).Trim().ToLowerInvariant())
}

$ownerFilesReport = Read-JsonReport $OwnerFilesPath
$rows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'sent', 'accepted', 'completed', 'blocked')
$expectedKeys = @{}
$seenKeys = @{}
$rowNumber = 1

if (-not $ownerFilesReport) {
    Add-Issue $issues 'blocker' 0 '' '' 'owner_manifest' 'missing_owner_manifest' 'owner files manifest is missing.'
} else {
    foreach ($ownerFile in @($ownerFilesReport.files)) {
        $key = Get-SignoffKey $ownerFile.owner $ownerFile.slug
        $expectedKeys[$key] = $ownerFile
    }
}

if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
    Add-Issue $issues 'blocker' 0 '' '' 'csv_path' 'missing_signoff_csv' 'owner signoff CSV is missing.'
}

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }
    $key = Get-SignoffKey $row.owner $row.slug

    if ($seenKeys.ContainsKey($key)) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.slug 'owner' 'duplicate_signoff_row' 'owner signoff row is duplicated.'
    } else {
        $seenKeys[$key] = $true
    }

    if (-not $expectedKeys.ContainsKey($key)) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.slug 'owner' 'unexpected_signoff_row' 'owner signoff row does not match the owner file manifest.'
    } else {
        $ownerFile = $expectedKeys[$key]
        if ([int]$row.action_count -ne [int]$ownerFile.count) {
            Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'action_count' 'action_count_mismatch' 'action_count does not match the owner file manifest.'
        }
        if ([int]$row.blockers -ne [int]$ownerFile.blockers) {
            Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'blockers' 'blocker_count_mismatch' 'blocker count does not match the owner file manifest.'
        }
        if ([int]$row.warnings -ne [int]$ownerFile.warnings) {
            Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'warnings' 'warning_count_mismatch' 'warning count does not match the owner file manifest.'
        }
    }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.slug 'status' 'invalid_status' 'status must be pending, sent, accepted, completed, or blocked.'
        continue
    }

    if ($status -in @('sent', 'accepted', 'completed')) {
        if (Test-Blank $row.recipient) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'recipient' 'recipient_required' 'recipient is required once a package is sent.' }
        if (Test-Blank $row.sent_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'sent_at' 'sent_at is required once a package is sent.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'evidence_ref' 'evidence_ref is recommended once a package is sent.' }
    }

    if ($status -in @('accepted', 'completed')) {
        if (Test-Blank $row.accepted_by) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'accepted_by' 'accepted_by is required once a package is accepted.' }
        if (Test-Blank $row.accepted_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'accepted_at' 'accepted_at is required once a package is accepted.' }
    }

    if ($status -eq 'completed') {
        if (Test-Blank $row.completed_by) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'completed_by' 'completed_by is required once a package is completed.' }
        if (Test-Blank $row.completed_at) { Add-Issue $issues 'warning' $rowNumber $row.owner $row.slug 'completed_at' 'completed_at is required once a package is completed.' }
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.owner $row.slug 'notes' 'blocked_notes_required' 'notes are required when status is blocked.'
    }
}

foreach ($key in $expectedKeys.Keys) {
    if (-not $seenKeys.ContainsKey($key)) {
        $ownerFile = $expectedKeys[$key]
        Add-Issue $issues 'blocker' 0 $ownerFile.owner $ownerFile.slug 'owner' 'missing_signoff_row' 'owner file manifest entry is missing from the signoff CSV.'
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
    note = 'This report validates owner-specific next-action handoff signoff fields. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_rows = $rows.Count
        expected_owners = $expectedKeys.Count
        blockers = $blockers
        warnings = $warnings
        status_counts = $statusCounts
    }
    owner_manifest = $OwnerFilesPath
    signoff_csv = $CsvPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions owner signoff validation written to $ReportPath"
