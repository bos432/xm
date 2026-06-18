param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files-validation.json"),
    [string]$OwnerFilesPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $owner, $slug, $file, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        owner = $owner
        slug = $slug
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

$ownerFilesReport = Read-JsonReport $OwnerFilesPath
$issues = New-Object System.Collections.Generic.List[object]
$expectedZipEntryNames = New-Object System.Collections.Generic.List[string]
$ownerFileCount = 0
$csvCountMismatches = 0
$missingOwnerFiles = 0
$zipPath = $null
$zipEntryNames = @()

if (-not $ownerFilesReport) {
    Add-Issue $issues 'blocker' '' '' $OwnerFilesPath 'missing_owner_manifest' 'owner files manifest is missing.'
} else {
    $zipPath = $ownerFilesReport.zip
    $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($OwnerFilesPath))

    if (Test-Blank $zipPath) {
        Add-Issue $issues 'blocker' '' '' '' 'missing_zip_path' 'owner files manifest does not define a ZIP path.'
    } elseif (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        Add-Issue $issues 'blocker' '' '' $zipPath 'missing_zip_file' 'owner files ZIP is missing.'
    } else {
        $zipEntryNames = Get-ZipEntryNames $zipPath
    }

    $ownerFileEntries = @($ownerFilesReport.files)
    $ownerFileCount = $ownerFileEntries.Count
    if ($ownerFilesReport.owner_count -ne $ownerFileCount) {
        Add-Issue $issues 'warning' '' '' $OwnerFilesPath 'owner_count_mismatch' 'owner_count does not match the number of owner file entries.'
    }

    foreach ($ownerFile in $ownerFileEntries) {
        $owner = $ownerFile.owner
        $slug = $ownerFile.slug

        if (Test-Blank $owner) {
            Add-Issue $issues 'warning' $owner $slug $OwnerFilesPath 'blank_owner' 'owner file entry has a blank owner.'
        }

        if (Test-Blank $slug) {
            Add-Issue $issues 'blocker' $owner $slug $OwnerFilesPath 'blank_slug' 'owner file entry has a blank slug.'
        }

        foreach ($pathField in @('csv', 'markdown')) {
            $path = $ownerFile.$pathField
            if (Test-Blank $path) {
                Add-Issue $issues 'blocker' $owner $slug $OwnerFilesPath "blank_${pathField}_path" "owner file entry has a blank $pathField path."
                continue
            }

            $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($path))
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                $missingOwnerFiles++
                Add-Issue $issues 'blocker' $owner $slug $path "missing_${pathField}_file" "owner-specific $pathField file is missing."
            }
        }

        if ([int]$ownerFile.blockers -gt 0) {
            foreach ($pathField in @('blocker_csv', 'blocker_markdown')) {
                $path = $ownerFile.$pathField
                if (Test-Blank $path) {
                    Add-Issue $issues 'blocker' $owner $slug $OwnerFilesPath "blank_${pathField}_path" "owner file entry has blockers but a blank $pathField path."
                    continue
                }

                $expectedZipEntryNames.Add([System.IO.Path]::GetFileName($path))
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                    $missingOwnerFiles++
                    Add-Issue $issues 'blocker' $owner $slug $path "missing_${pathField}_file" "owner-specific $pathField file is missing."
                }
            }
        }

        if (-not (Test-Blank $ownerFile.csv) -and (Test-Path -LiteralPath $ownerFile.csv -PathType Leaf)) {
            $csvRows = @(Import-Csv -LiteralPath $ownerFile.csv -Encoding UTF8)
            if ($csvRows.Count -ne [int]$ownerFile.count) {
                $csvCountMismatches++
                Add-Issue $issues 'warning' $owner $slug $ownerFile.csv 'csv_count_mismatch' "CSV row count ($($csvRows.Count)) does not match manifest count ($($ownerFile.count))."
            }
        }

        if ([int]$ownerFile.blockers -gt 0 -and -not (Test-Blank $ownerFile.blocker_csv) -and (Test-Path -LiteralPath $ownerFile.blocker_csv -PathType Leaf)) {
            $blockerCsvRows = @(Import-Csv -LiteralPath $ownerFile.blocker_csv -Encoding UTF8)
            if ($blockerCsvRows.Count -ne [int]$ownerFile.blockers) {
                $csvCountMismatches++
                Add-Issue $issues 'warning' $owner $slug $ownerFile.blocker_csv 'blocker_csv_count_mismatch' "Blocker CSV row count ($($blockerCsvRows.Count)) does not match manifest blocker count ($($ownerFile.blockers))."
            }
        }
    }
}

$expectedZipEntryNames = @($expectedZipEntryNames.ToArray() | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$zipEntryNames = @($zipEntryNames | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
$missingZipEntries = @($expectedZipEntryNames | Where-Object { $zipEntryNames -notcontains $_ })
$extraZipEntries = @($zipEntryNames | Where-Object { $expectedZipEntryNames -notcontains $_ })

foreach ($entry in $missingZipEntries) {
    Add-Issue $issues 'blocker' '' '' $zipPath 'missing_zip_entry' "ZIP is missing expected entry: $entry"
}

foreach ($entry in $extraZipEntries) {
    Add-Issue $issues 'warning' '' '' $zipPath 'extra_zip_entry' "ZIP contains an unexpected entry: $entry"
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count
$zipExists = -not (Test-Blank $zipPath) -and (Test-Path -LiteralPath $zipPath -PathType Leaf)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates owner-specific next action handoff files and ZIP contents. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $ownerFilesReport) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        owner_files = $ownerFileCount
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $zipPath).Length } else { $null }
        expected_zip_entries = $expectedZipEntryNames.Count
        zip_entries = $zipEntryNames.Count
        missing_zip_entries = $missingZipEntries.Count
        extra_zip_entries = $extraZipEntries.Count
        missing_owner_files = $missingOwnerFiles
        csv_count_mismatches = $csvCountMismatches
        blockers = $blockers
        warnings = $warnings
    }
    owner_manifest = $OwnerFilesPath
    owner_zip = $zipPath
    missing_zip_entries = @($missingZipEntries)
    extra_zip_entries = @($extraZipEntries)
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions owner files validation written to $ReportPath"
