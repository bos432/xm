param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-validation.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff.csv"),
    [string]$WaveFilesPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.json")
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

function Add-Issue($issues, $severity, $rowNumber, $wave, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        row_number = $rowNumber
        wave = $wave
        field = $field
        code = $code
        message = $message
    })
}

$rows = Read-CsvRows $CsvPath
$waveFiles = Read-JsonReport $WaveFilesPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'mitigated', 'accepted_with_risk', 'blocked')
$rowNumber = 1

if (-not $waveFiles) {
    Add-Issue $issues 'blocker' 0 '' $WaveFilesPath 'missing_wave_files_manifest' 'wave files manifest is missing.'
} else {
    $expectedWaves = @($waveFiles.files.waves | ForEach-Object { [string]$_.wave })
    $actualWaves = @($rows | ForEach-Object { [string]$_.wave })
    $duplicateWaves = @($actualWaves | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    $missingWaves = @($expectedWaves | Where-Object { $actualWaves -notcontains $_ })
    $extraWaves = @($actualWaves | Where-Object { $expectedWaves -notcontains $_ })

    foreach ($wave in $duplicateWaves) {
        Add-Issue $issues 'blocker' 0 $wave 'wave' 'duplicate_wave' "signoff CSV contains duplicate wave: $wave"
    }
    foreach ($wave in $missingWaves) {
        Add-Issue $issues 'blocker' 0 $wave 'wave' 'missing_wave' "signoff CSV is missing wave: $wave"
    }
    foreach ($wave in $extraWaves) {
        Add-Issue $issues 'blocker' 0 $wave 'wave' 'extra_wave' "signoff CSV contains a wave that is not in the wave manifest: $wave"
    }
}

foreach ($row in @($rows)) {
    $rowNumber++
    $status = ([string]$row.status).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    if ($validStatuses -notcontains $status) {
        Add-Issue $issues 'blocker' $rowNumber $row.wave 'status' 'invalid_status' 'status must be pending, mitigated, accepted_with_risk, or blocked.'
        continue
    }

    if ($status -in @('mitigated', 'accepted_with_risk', 'blocked')) {
        if (Test-Blank $row.owner) { Add-Issue $issues 'warning' $rowNumber $row.wave 'owner' 'owner_required' 'owner is required once a remediation wave is reviewed.' }
        if (Test-Blank $row.resolved_by) { Add-Issue $issues 'warning' $rowNumber $row.wave 'resolved_by' 'resolved_by_required' 'resolved_by is required once a remediation wave is reviewed.' }
        if (Test-Blank $row.resolved_at) { Add-Issue $issues 'warning' $rowNumber $row.wave 'resolved_at' 'resolved_at_required' 'resolved_at is required once a remediation wave is reviewed.' }
        if (Test-Blank $row.evidence_ref) { Add-Issue $issues 'warning' $rowNumber $row.wave 'evidence_ref' 'evidence_required' 'evidence_ref is required once a remediation wave is reviewed.' }
    }

    if (($status -eq 'accepted_with_risk') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'warning' $rowNumber $row.wave 'notes' 'risk_notes_required' 'notes are required when accepting residual wave risk.'
    }

    if (($status -eq 'blocked') -and (Test-Blank $row.notes)) {
        Add-Issue $issues 'blocker' $rowNumber $row.wave 'notes' 'blocked_notes_required' 'notes are required when a remediation wave remains blocked.'
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
    note = 'This report validates manual public executable remediation wave signoff fields. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        signoff_rows = $rows.Count
        expected_waves = if ($waveFiles) { @($waveFiles.files.waves).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
        status_counts = $statusCounts
    }
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff validation written to $ReportPath"
