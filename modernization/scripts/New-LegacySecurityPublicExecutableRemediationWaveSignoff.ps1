param(
    [string]$WaveFilesPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.json"),
    [string]$PlanPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff.csv")
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

function Get-Field($row, $name, $default = '') {
    if ($null -eq $row) { return $default }
    if ($row.PSObject.Properties.Name -contains $name) { return $row.$name }
    return $default
}

function Get-Key($value) {
    return ([string]$value).Trim().ToLowerInvariant()
}

$waveFiles = Read-JsonReport $WaveFilesPath
$plan = Read-JsonReport $PlanPath
$existingRows = Read-CsvRows $CsvPath
$existingByWave = @{}
foreach ($row in @($existingRows)) {
    $key = Get-Key (Get-Field $row 'wave')
    if (-not (Test-Blank $key)) { $existingByWave[$key] = $row }
}

$validStatuses = @('pending', 'mitigated', 'accepted_with_risk', 'blocked')
$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]

if ($waveFiles -and $waveFiles.files.waves) {
    foreach ($wave in @($waveFiles.files.waves | Sort-Object wave)) {
        $waveNumber = [int]$wave.wave
        $key = Get-Key $waveNumber
        $existingRow = if ($existingByWave.ContainsKey($key)) { $existingByWave[$key] } else { $null }
        $planWave = if ($plan) { @($plan.waves | Where-Object { [int]$_.wave -eq $waveNumber } | Select-Object -First 1) } else { @() }
        $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
        if (Test-Blank $status) { $status = 'pending' }

        if ($validStatuses -notcontains $status) {
            $warnings.Add([pscustomobject][ordered]@{
                code = 'invalid_status'
                wave = $waveNumber
                value = $status
                message = 'status must be pending, mitigated, accepted_with_risk, or blocked.'
            })
        }

        $rows.Add([pscustomobject][ordered]@{
            status = $status
            wave = $waveNumber
            title = $wave.title
            total_files = $wave.total_files
            pending_files = $wave.pending_files
            blocker_files = $wave.blocker_files
            warning_files = $wave.warning_files
            acceptance = if ($planWave.Count -gt 0) { $planWave[0].acceptance } else { '' }
            source_csv = $wave.csv
            source_markdown = $wave.markdown
            owner = Get-Field $existingRow 'owner' 'security_owner'
            resolved_by = Get-Field $existingRow 'resolved_by'
            resolved_at = Get-Field $existingRow 'resolved_at'
            evidence_ref = Get-Field $existingRow 'evidence_ref'
            notes = Get-Field $existingRow 'notes'
        })
    }
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pendingItems = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$mitigatedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'mitigated' }).Count
$riskAcceptedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$blockedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks public executable remediation wave mitigation and risk acceptance. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $waveFiles) { 'missing' } elseif ($invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif (($mitigatedItems + $riskAcceptedItems) -eq $rows.Count -and $rows.Count -gt 0) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        pending_items = $pendingItems
        mitigated_items = $mitigatedItems
        accepted_with_risk_items = $riskAcceptedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        source_wave_files_status = if ($waveFiles) { $waveFiles.overall_status } else { 'missing' }
    }
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff written to $ReportPath"
Write-Host "Legacy public executable remediation wave signoff CSV written to $CsvPath"
