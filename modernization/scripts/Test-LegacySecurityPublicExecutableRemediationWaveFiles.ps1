param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files-validation.json"),
    [string]$WaveFilesPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.json")
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

function Add-Issue($issues, $severity, $wave, $file, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        wave = $wave
        file = $file
        code = $code
        message = $message
    })
}

function Get-ZipEntryNames($zipPath) {
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { return @() }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        return @($zip.Entries | ForEach-Object { $_.Name })
    } finally {
        $zip.Dispose()
    }
}

$waveFiles = Read-JsonReport $WaveFilesPath
$issues = New-Object System.Collections.Generic.List[object]
$expectedZipEntryNames = New-Object System.Collections.Generic.List[string]
$zipPath = $null
$zipEntryNames = @()
$waveCount = 0
$missingWaveFiles = 0
$csvCountMismatches = 0

if (-not $waveFiles) {
    Add-Issue $issues 'blocker' '' $WaveFilesPath 'missing_wave_files_manifest' 'wave files manifest is missing.'
} else {
    $zipPath = $waveFiles.files.zip
    $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($WaveFilesPath))

    if (Test-Blank $zipPath) {
        Add-Issue $issues 'blocker' '' '' 'missing_zip_path' 'wave files manifest does not define a ZIP path.'
    } elseif (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        Add-Issue $issues 'blocker' '' $zipPath 'missing_zip_file' 'wave files ZIP is missing.'
    } else {
        $zipEntryNames = Get-ZipEntryNames $zipPath
    }

    $waves = @($waveFiles.files.waves)
    $waveCount = $waves.Count
    if ($waveFiles.summary.waves -ne $waveCount) {
        Add-Issue $issues 'warning' '' $WaveFilesPath 'wave_count_mismatch' "summary waves ($($waveFiles.summary.waves)) does not match manifest wave entries ($waveCount)."
    }

    foreach ($wave in $waves) {
        foreach ($pathField in @('csv', 'markdown')) {
            $path = $wave.$pathField
            if (Test-Blank $path) {
                Add-Issue $issues 'blocker' $wave.wave $WaveFilesPath "blank_${pathField}_path" "wave $($wave.wave) has a blank $pathField path."
                continue
            }

            $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($path))
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                $missingWaveFiles++
                Add-Issue $issues 'blocker' $wave.wave $path "missing_${pathField}_file" "wave $($wave.wave) $pathField file is missing."
            }
        }

        if (-not (Test-Blank $wave.csv) -and (Test-Path -LiteralPath $wave.csv -PathType Leaf)) {
            $rows = Read-CsvRows $wave.csv
            if ($rows.Count -ne [int]$wave.total_files) {
                $csvCountMismatches++
                Add-Issue $issues 'blocker' $wave.wave $wave.csv 'csv_count_mismatch' "wave $($wave.wave) CSV row count ($($rows.Count)) does not match total_files ($($wave.total_files))."
            }
        }
    }
}

$expectedZipEntryNames = @($expectedZipEntryNames.ToArray() | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$zipEntryNames = @($zipEntryNames | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$missingZipEntries = @($expectedZipEntryNames | Where-Object { $zipEntryNames -notcontains $_ })
$extraZipEntries = @($zipEntryNames | Where-Object { $expectedZipEntryNames -notcontains $_ })

foreach ($entry in $missingZipEntries) {
    Add-Issue $issues 'blocker' '' $zipPath 'missing_zip_entry' "ZIP is missing expected entry: $entry"
}

foreach ($entry in $extraZipEntries) {
    Add-Issue $issues 'warning' '' $zipPath 'extra_zip_entry' "ZIP contains an unexpected entry: $entry"
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$zipExists = -not (Test-Blank $zipPath) -and (Test-Path -LiteralPath $zipPath -PathType Leaf)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates wave-specific public executable remediation files and ZIP contents. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $waveFiles) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        waves = $waveCount
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $zipPath).Length } else { $null }
        expected_zip_entries = $expectedZipEntryNames.Count
        zip_entries = $zipEntryNames.Count
        missing_zip_entries = $missingZipEntries.Count
        extra_zip_entries = $extraZipEntries.Count
        missing_wave_files = $missingWaveFiles
        csv_count_mismatches = $csvCountMismatches
        blockers = $blockers
        warnings = $warnings
    }
    wave_files_manifest = $WaveFilesPath
    wave_files_zip = $zipPath
    missing_zip_entries = @($missingZipEntries)
    extra_zip_entries = @($extraZipEntries)
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave files validation written to $ReportPath"
