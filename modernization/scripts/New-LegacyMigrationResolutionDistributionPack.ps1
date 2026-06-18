param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.md"),
    [string]$ZipPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.zip"),
    [string]$OwnerTemplateRowWorklistsPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-owner-template-row-worklists.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-PackItem($file) {
    $exists = Test-Path -LiteralPath $file.path -PathType Leaf
    return [pscustomobject][ordered]@{
        owner = $file.owner
        template = $file.template
        rows = $file.rows
        p1_rows = $file.p1_rows
        blocked_rows = $file.blocked_rows
        csv_path = $file.path
        exists = $exists
        size_bytes = if ($exists) { (Get-Item -LiteralPath $file.path).Length } else { $null }
        assignment = if ($file.owner -eq 'business_reviewer') { 'Review business decisions and approvals.' } elseif ($file.owner -eq 'migration_engineer') { 'Fill mapping ids and request business approval.' } else { 'Review and complete assigned rows.' }
    }
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

$source = Read-JsonReport $OwnerTemplateRowWorklistsPath
$items = New-Object System.Collections.Generic.List[object]

if ($source -and $source.files) {
    foreach ($file in @($source.files)) {
        $items.Add((New-PackItem $file))
    }
}

$missingFiles = @($items.ToArray() | Where-Object { -not $_.exists })
$blockedRows = @($items.ToArray() | Measure-Object -Property blocked_rows -Sum).Sum
$p1Rows = @($items.ToArray() | Measure-Object -Property p1_rows -Sum).Sum
$rowCount = @($items.ToArray() | Measure-Object -Property rows -Sum).Sum

@($items.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Migration Resolution Distribution Pack'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines 'This package contains owner-and-template row-level CSV files for manual resolution work. It does not edit templates, copy files, import records, or write database records.'
Add-Line $lines
Add-Line $lines '## Summary'
Add-Line $lines
Add-Line $lines ('- Files: ' + $items.Count)
Add-Line $lines ('- Rows: ' + $rowCount)
Add-Line $lines ('- P1 rows: ' + $p1Rows)
Add-Line $lines ('- Blocked rows: ' + $blockedRows)
Add-Line $lines
Add-Line $lines '## Assignments'
Add-Line $lines
Add-Line $lines '| Owner | Template | Rows | P1 | Blocked | File | Assignment |'
Add-Line $lines '| --- | --- | ---: | ---: | ---: | --- | --- |'
foreach ($item in @($items.ToArray())) {
    Add-Line $lines "| $($item.owner) | $($item.template) | $($item.rows) | $($item.p1_rows) | $($item.blocked_rows) | $([System.IO.Path]::GetFileName($item.csv_path)) | $($item.assignment) |"
}
Add-Line $lines
Add-Line $lines '## Completion Rule'
Add-Line $lines
Add-Line $lines 'After assigned rows are completed, update the source resolution templates, rerun the full report pipeline, and review the acceptance gate.'
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $ZipPath -Force
}

$zipInputs = New-Object System.Collections.Generic.List[string]
foreach ($item in @($items.ToArray())) {
    if ($item.exists) { $zipInputs.Add($item.csv_path) }
}
$zipInputs.Add($CsvPath)
$zipInputs.Add($MarkdownPath)

if ($zipInputs.Count -gt 0) {
    Compress-Archive -LiteralPath @($zipInputs.ToArray()) -DestinationPath $ZipPath -Force
}

$zipExists = Test-Path -LiteralPath $ZipPath -PathType Leaf
$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This distribution pack summarizes and packages owner-and-template row-level CSV files. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if (-not $source) { 'missing' } elseif ($missingFiles.Count -gt 0) { 'blocked' } elseif ($rowCount -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        file_count = $items.Count
        existing_files = @($items.ToArray() | Where-Object { $_.exists }).Count
        missing_files = $missingFiles.Count
        row_work_items = $rowCount
        p1_rows = $p1Rows
        blocked_rows = $blockedRows
        zip_exists = $zipExists
        zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $ZipPath).Length } else { $null }
    }
    files = [ordered]@{
        manifest_csv = $CsvPath
        markdown = $MarkdownPath
        zip = $ZipPath
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution distribution pack written to $ReportPath"
Write-Host "Legacy migration resolution distribution pack ZIP written to $ZipPath"
