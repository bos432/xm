param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json"),
    [string]$HandoffPackPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json")
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

function Add-Issue($issues, $severity, $file, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
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

$handoffPack = Read-JsonReport $HandoffPackPath
$issues = New-Object System.Collections.Generic.List[object]
$expectedZipEntryNames = New-Object System.Collections.Generic.List[string]
$zipPath = $null
$zipEntryNames = @()
$handoffFiles = 0
$missingRequiredFiles = 0
$csvCountMismatches = 0

if (-not $handoffPack) {
    Add-Issue $issues 'blocker' $HandoffPackPath 'missing_handoff_pack' 'handoff pack manifest is missing.'
} else {
    $csvPath = $handoffPack.files.csv
    $markdownPath = $handoffPack.files.markdown
    $zipPath = $handoffPack.files.zip
    $items = @($handoffPack.items)
    $handoffFiles = $items.Count

    $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($HandoffPackPath))

    foreach ($path in @($csvPath, $markdownPath)) {
        if (Test-Blank $path) {
            Add-Issue $issues 'blocker' $HandoffPackPath 'blank_handoff_file_path' 'handoff pack does not define CSV or Markdown output path.'
        } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Issue $issues 'blocker' $path 'missing_handoff_file' 'handoff CSV or Markdown file is missing.'
        } else {
            $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($path))
        }
    }

    if (Test-Blank $zipPath) {
        Add-Issue $issues 'blocker' $HandoffPackPath 'missing_zip_path' 'handoff pack does not define a ZIP path.'
    } elseif (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        Add-Issue $issues 'blocker' $zipPath 'missing_zip_file' 'handoff ZIP is missing.'
    } else {
        $zipEntryNames = Get-ZipEntryNames $zipPath
    }

    if ($handoffPack.summary.handoff_files -ne $handoffFiles) {
        Add-Issue $issues 'warning' $HandoffPackPath 'handoff_file_count_mismatch' "summary handoff_files ($($handoffPack.summary.handoff_files)) does not match item entries ($handoffFiles)."
    }

    if (-not (Test-Blank $csvPath) -and (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
        $csvRows = Read-CsvRows $csvPath
        if ($csvRows.Count -ne $handoffFiles) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' $csvPath 'csv_count_mismatch' "handoff CSV row count ($($csvRows.Count)) does not match item entries ($handoffFiles)."
        }
    }

    foreach ($item in $items) {
        if (Test-Blank $item.key) {
            Add-Issue $issues 'warning' $HandoffPackPath 'blank_item_key' 'handoff item has a blank key.'
        }
        if (Test-Blank $item.path) {
            Add-Issue $issues 'blocker' $HandoffPackPath 'blank_item_path' "handoff item $($item.key) has a blank path."
            continue
        }

        $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($item.path))
        if ($item.required -and -not (Test-Path -LiteralPath $item.path -PathType Leaf)) {
            $missingRequiredFiles++
            Add-Issue $issues 'blocker' $item.path 'missing_required_file' "required handoff item is missing: $($item.key)."
        }
    }

    if ($handoffPack.summary.missing_required -ne $missingRequiredFiles) {
        Add-Issue $issues 'blocker' $HandoffPackPath 'missing_required_count_mismatch' "summary missing_required ($($handoffPack.summary.missing_required)) does not match missing required item files ($missingRequiredFiles)."
    }
}

$expectedZipEntryNames = @($expectedZipEntryNames.ToArray() | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$zipEntryNames = @($zipEntryNames | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$missingZipEntries = @($expectedZipEntryNames | Where-Object { $zipEntryNames -notcontains $_ })
$extraZipEntries = @($zipEntryNames | Where-Object { $expectedZipEntryNames -notcontains $_ })

foreach ($entry in $missingZipEntries) {
    Add-Issue $issues 'blocker' $zipPath 'missing_zip_entry' "ZIP is missing expected entry: $entry"
}

foreach ($entry in $extraZipEntries) {
    Add-Issue $issues 'warning' $zipPath 'extra_zip_entry' "ZIP contains an unexpected entry: $entry"
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$zipExists = -not (Test-Blank $zipPath) -and (Test-Path -LiteralPath $zipPath -PathType Leaf)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the public executable remediation wave signoff handoff pack and ZIP contents. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $handoffPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        handoff_files = $handoffFiles
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $zipPath).Length } else { $null }
        expected_zip_entries = $expectedZipEntryNames.Count
        zip_entries = $zipEntryNames.Count
        missing_zip_entries = $missingZipEntries.Count
        extra_zip_entries = $extraZipEntries.Count
        missing_required_files = $missingRequiredFiles
        csv_count_mismatches = $csvCountMismatches
        blockers = $blockers
        warnings = $warnings
    }
    handoff_pack = $HandoffPackPath
    handoff_zip = $zipPath
    missing_zip_entries = @($missingZipEntries)
    extra_zip_entries = @($extraZipEntries)
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff handoff pack validation written to $ReportPath"
