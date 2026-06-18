param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack-validation.json"),
    [string]$EvidencePackPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-evidence-pack.json")
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

$evidencePack = Read-JsonReport $EvidencePackPath
$issues = New-Object System.Collections.Generic.List[object]
$expectedZipEntryNames = New-Object System.Collections.Generic.List[string]
$zipPath = $null
$zipEntryNames = @()
$evidenceFiles = 0
$missingRequiredFiles = 0
$itemExistenceMismatches = 0
$csvCountMismatches = 0
$statusMismatches = 0
$expectedOverallStatus = 'missing'

if (-not $evidencePack) {
    Add-Issue $issues 'blocker' $EvidencePackPath 'missing_evidence_pack' 'go-live evidence pack manifest is missing.'
} else {
    $csvPath = $evidencePack.files.csv
    $markdownPath = $evidencePack.files.markdown
    $zipPath = $evidencePack.files.zip
    $items = @($evidencePack.items)
    $evidenceFiles = $items.Count

    foreach ($path in @($csvPath, $markdownPath)) {
        if (Test-Blank $path) {
            Add-Issue $issues 'blocker' $EvidencePackPath 'blank_evidence_output_path' 'evidence pack does not define CSV or Markdown output path.'
        } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Issue $issues 'blocker' $path 'missing_evidence_output_file' 'evidence CSV or Markdown file is missing.'
        } else {
            $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($path))
        }
    }

    if (Test-Blank $zipPath) {
        Add-Issue $issues 'blocker' $EvidencePackPath 'missing_zip_path' 'evidence pack does not define a ZIP path.'
    } elseif (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        Add-Issue $issues 'blocker' $zipPath 'missing_zip_file' 'evidence ZIP is missing.'
    } else {
        $zipEntryNames = Get-ZipEntryNames $zipPath
    }

    if ($evidencePack.summary.evidence_files -ne $evidenceFiles) {
        Add-Issue $issues 'warning' $EvidencePackPath 'evidence_file_count_mismatch' "summary evidence_files ($($evidencePack.summary.evidence_files)) does not match item entries ($evidenceFiles)."
    }

    if (-not (Test-Blank $csvPath) -and (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
        $csvRows = Read-CsvRows $csvPath
        if ($csvRows.Count -ne $evidenceFiles) {
            $csvCountMismatches++
            Add-Issue $issues 'blocker' $csvPath 'csv_count_mismatch' "evidence CSV row count ($($csvRows.Count)) does not match item entries ($evidenceFiles)."
        }
    }

    foreach ($item in $items) {
        if (Test-Blank $item.key) {
            Add-Issue $issues 'warning' $EvidencePackPath 'blank_item_key' 'evidence item has a blank key.'
        }
        if (Test-Blank $item.path) {
            Add-Issue $issues 'blocker' $EvidencePackPath 'blank_item_path' "evidence item $($item.key) has a blank path."
            continue
        }

        $diskExists = Test-Path -LiteralPath $item.path -PathType Leaf
        if ([bool]$item.exists -ne [bool]$diskExists) {
            $itemExistenceMismatches++
            Add-Issue $issues 'blocker' $item.path 'item_exists_mismatch' "evidence item $($item.key) exists flag ($($item.exists)) does not match disk existence ($diskExists)."
        }

        if ($item.required -and -not $diskExists) {
            $missingRequiredFiles++
            Add-Issue $issues 'blocker' $item.path 'missing_required_file' "required evidence item is missing: $($item.key)."
        }

        if ($diskExists) {
            $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($item.path))
        }
    }

    if ($evidencePack.summary.missing_required -ne $missingRequiredFiles) {
        Add-Issue $issues 'blocker' $EvidencePackPath 'missing_required_count_mismatch' "summary missing_required ($($evidencePack.summary.missing_required)) does not match missing required item files ($missingRequiredFiles)."
    }

    if (@($evidencePack.missing_required).Count -ne $missingRequiredFiles) {
        Add-Issue $issues 'blocker' $EvidencePackPath 'missing_required_list_mismatch' "missing_required list count ($(@($evidencePack.missing_required).Count)) does not match missing required item files ($missingRequiredFiles)."
    }

    $expectedOverallStatus = if ($missingRequiredFiles -gt 0) { 'blocked' } elseif ($evidencePack.summary.go_live_gate_status -ne 'ready') { 'not_ready' } else { 'ready' }
    if ($evidencePack.overall_status -ne $expectedOverallStatus) {
        $statusMismatches++
        Add-Issue $issues 'warning' $EvidencePackPath 'overall_status_mismatch' "overall_status ($($evidencePack.overall_status)) does not match expected status ($expectedOverallStatus)."
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
    note = 'This report validates the go-live evidence pack manifest and ZIP contents. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $evidencePack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        evidence_files = $evidenceFiles
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $zipPath).Length } else { $null }
        expected_zip_entries = $expectedZipEntryNames.Count
        zip_entries = $zipEntryNames.Count
        missing_zip_entries = $missingZipEntries.Count
        extra_zip_entries = $extraZipEntries.Count
        missing_required_files = $missingRequiredFiles
        item_existence_mismatches = $itemExistenceMismatches
        csv_count_mismatches = $csvCountMismatches
        status_mismatches = $statusMismatches
        expected_overall_status = $expectedOverallStatus
        blockers = $blockers
        warnings = $warnings
    }
    evidence_pack = $EvidencePackPath
    evidence_zip = $zipPath
    missing_zip_entries = @($missingZipEntries)
    extra_zip_entries = @($extraZipEntries)
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live evidence pack validation written to $ReportPath"
