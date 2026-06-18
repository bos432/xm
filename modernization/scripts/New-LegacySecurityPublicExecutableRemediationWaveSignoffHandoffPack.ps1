param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.md"),
    [string]$ZipPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-PackItem($key, $path, $purpose, $required = $true) {
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    return [pscustomobject][ordered]@{
        key = $key
        path = $path
        file_name = [System.IO.Path]::GetFileName($path)
        purpose = $purpose
        required = [bool]$required
        exists = $exists
        size_bytes = if ($exists) { (Get-Item -LiteralPath $path).Length } else { $null }
        updated_at = if ($exists) { (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') } else { $null }
    }
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

function Format-MarkdownText($value) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return '-' }
    return ([string]$value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

$waveFiles = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files.json')
$waveFilesValidation = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files-validation.json')
$signoff = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff.json')
$signoffValidation = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-validation.json')
$operatorPack = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json')
$operatorPackValidation = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json')

$items = New-Object System.Collections.Generic.List[object]
$items.Add((New-PackItem 'wave_files' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files.json') 'wave-specific public executable remediation file package manifest'))
$items.Add((New-PackItem 'wave_files_zip' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files.zip') 'ZIP package containing wave-specific CSV and Markdown files'))
$items.Add((New-PackItem 'wave_files_validation' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-files-validation.json') 'validation report for wave-specific remediation files and ZIP contents'))
$items.Add((New-PackItem 'wave_signoff' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff.json') 'JSON summary of public executable remediation wave signoff statuses'))
$items.Add((New-PackItem 'wave_signoff_csv' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff.csv') 'manual signoff CSV for public executable remediation waves'))
$items.Add((New-PackItem 'wave_signoff_validation' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-validation.json') 'validation report for public executable remediation wave signoff fields'))
$items.Add((New-PackItem 'wave_signoff_operator_pack' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack.json') 'operator pack for public executable remediation wave signoff'))
$items.Add((New-PackItem 'wave_signoff_operator_pack_validation' (Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json') 'validation report for public executable remediation wave signoff operator pack'))

$missingRequired = @($items.ToArray() | Where-Object { $_.required -and -not $_.exists })
$existingRequired = @($items.ToArray() | Where-Object { $_.required -and $_.exists })

@($items.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Public Executable Remediation Wave Signoff Handoff Pack'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines 'This handoff pack is preview-only. It packages remediation wave signoff reports for offline review and does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
Add-Line $lines
Add-Line $lines '## Summary'
Add-Line $lines
Add-Line $lines ('- Handoff files: ' + $items.Count)
Add-Line $lines ('- Missing required files: ' + $missingRequired.Count)
Add-Line $lines ('- Wave package status: ' + $(if ($waveFiles) { $waveFiles.overall_status } else { 'missing' }))
Add-Line $lines ('- Wave package validation: ' + $(if ($waveFilesValidation) { $waveFilesValidation.overall_status } else { 'missing' }))
Add-Line $lines ('- Wave signoff status: ' + $(if ($signoff) { $signoff.overall_status } else { 'missing' }))
Add-Line $lines ('- Pending signoff waves: ' + $(if ($signoff) { $signoff.summary.pending_items } else { 0 }))
Add-Line $lines ('- Operator pack status: ' + $(if ($operatorPack) { $operatorPack.overall_status } else { 'missing' }))
Add-Line $lines ('- Operator pack validation: ' + $(if ($operatorPackValidation) { $operatorPackValidation.overall_status } else { 'missing' }))
Add-Line $lines
Add-Line $lines '## Files'
Add-Line $lines
Add-Line $lines '| Key | Required | Exists | Size | File | Purpose |'
Add-Line $lines '| --- | --- | --- | ---: | --- | --- |'
foreach ($item in @($items.ToArray())) {
    Add-Line $lines "| $(Format-MarkdownText $item.key) | $($item.required) | $($item.exists) | $($item.size_bytes) | $(Format-MarkdownText $item.file_name) | $(Format-MarkdownText $item.purpose) |"
}
Add-Line $lines
Add-Line $lines '## Completion Rule'
Add-Line $lines
Add-Line $lines 'The handoff pack is sufficient for security-owner execution when required files exist, package validations are ready, and every wave is mitigated or accepted_with_risk.'
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $ZipPath -Force
}

$zipInputs = New-Object System.Collections.Generic.List[string]
foreach ($item in @($items.ToArray())) {
    if ($item.exists) { $zipInputs.Add($item.path) }
}
$zipInputs.Add($CsvPath)
$zipInputs.Add($MarkdownPath)
$zipInputs.Add($ReportPath)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This handoff pack packages public executable remediation wave signoff reports for offline review. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if ($missingRequired.Count -gt 0) { 'blocked' } elseif ($operatorPackValidation -and $operatorPackValidation.overall_status -eq 'ready' -and $signoff -and $signoff.overall_status -eq 'ready' -and $operatorPack -and $operatorPack.overall_status -eq 'ready') { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        handoff_files = $items.Count
        existing_required = $existingRequired.Count
        missing_required = $missingRequired.Count
        wave_package_status = if ($waveFiles) { $waveFiles.overall_status } else { 'missing' }
        wave_package_validation_status = if ($waveFilesValidation) { $waveFilesValidation.overall_status } else { 'missing' }
        wave_signoff_status = if ($signoff) { $signoff.overall_status } else { 'missing' }
        wave_signoff_pending_items = if ($signoff) { $signoff.summary.pending_items } else { 0 }
        wave_signoff_operator_pack_status = if ($operatorPack) { $operatorPack.overall_status } else { 'missing' }
        wave_signoff_operator_pack_validation_status = if ($operatorPackValidation) { $operatorPackValidation.overall_status } else { 'missing' }
        zip_exists = $false
        zip_size_bytes = $null
    }
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
        zip = $ZipPath
    }
    missing_required = @($missingRequired | ForEach-Object { $_.key })
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($zipInputs.Count -gt 0) {
    Compress-Archive -LiteralPath @($zipInputs.ToArray()) -DestinationPath $ZipPath -Force
}

$zipExists = Test-Path -LiteralPath $ZipPath -PathType Leaf
$report.summary.zip_exists = $zipExists
$report.summary.zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $ZipPath).Length } else { $null }
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host "Legacy public executable remediation wave signoff handoff pack written to $ReportPath"
Write-Host "Legacy public executable remediation wave signoff handoff ZIP written to $ZipPath"
