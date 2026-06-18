param(
    [string]$PlanPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.json"),
    [string]$ZipPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-files.zip")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

function Format-MarkdownText($value) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return '-' }
    return ([string]$value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Write-WaveMarkdown($path, $wave, $items) {
    $lines = New-Object System.Collections.Generic.List[string]
    Add-Line $lines "# Legacy Public Executable Remediation Wave $($wave.wave)"
    Add-Line $lines
    Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
    Add-Line $lines
    Add-Line $lines 'This wave file is preview-only. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    Add-Line $lines
    Add-Line $lines '## Summary'
    Add-Line $lines
    Add-Line $lines ('- Title: ' + $wave.title)
    Add-Line $lines ('- Status: ' + $wave.status)
    Add-Line $lines ('- Total files: ' + $wave.total_files)
    Add-Line $lines ('- Pending files: ' + $wave.pending_files)
    Add-Line $lines ('- Blocker files: ' + $wave.blocker_files)
    Add-Line $lines ('- Warning files: ' + $wave.warning_files)
    Add-Line $lines ('- Acceptance: ' + $wave.acceptance)
    Add-Line $lines
    Add-Line $lines '## Files'
    Add-Line $lines
    Add-Line $lines '| ID | Severity | Status | Category | Relative Path | Action | Evidence | Notes |'
    Add-Line $lines '| ---: | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($item in @($items)) {
        Add-Line $lines "| $($item.item_id) | $(Format-MarkdownText $item.severity) | $(Format-MarkdownText $item.status) | $(Format-MarkdownText $item.category) | $(Format-MarkdownText $item.relative_path) | $(Format-MarkdownText $item.recommended_action) | $(Format-MarkdownText $item.evidence_ref) | $(Format-MarkdownText $item.notes) |"
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
}

$plan = Read-JsonReport $PlanPath
$waveFiles = New-Object System.Collections.Generic.List[object]
$zipInputs = New-Object System.Collections.Generic.List[string]

if ($plan) {
    foreach ($wave in @($plan.waves | Sort-Object wave)) {
        $waveNumber = [int]$wave.wave
        $waveItems = @($plan.items | Where-Object { [int]$_.wave -eq $waveNumber } | Sort-Object item_id)
        $waveCsvPath = Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave.$waveNumber.csv"
        $waveMarkdownPath = Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave.$waveNumber.md"

        $waveItems | Export-Csv -LiteralPath $waveCsvPath -Encoding UTF8 -NoTypeInformation
        Write-WaveMarkdown $waveMarkdownPath $wave $waveItems

        $zipInputs.Add($waveCsvPath)
        $zipInputs.Add($waveMarkdownPath)
        $waveFiles.Add([pscustomobject][ordered]@{
            wave = $waveNumber
            title = $wave.title
            status = $wave.status
            total_files = $wave.total_files
            pending_files = $wave.pending_files
            blocker_files = $wave.blocker_files
            warning_files = $wave.warning_files
            csv = $waveCsvPath
            markdown = $waveMarkdownPath
        })
    }
}

$zipExists = $false
$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report packages wave-specific public executable remediation files. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $plan) { 'missing' } elseif ($plan.overall_status -eq 'ready') { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        waves = $waveFiles.Count
        total_files = if ($plan) { $plan.summary.total_files } else { 0 }
        pending_files = if ($plan) { $plan.summary.pending_files } else { 0 }
        ready_waves = if ($plan) { $plan.summary.ready_waves } else { 0 }
        pending_waves = if ($plan) { $plan.summary.pending_waves } else { 0 }
        next_wave = if ($plan) { $plan.summary.next_wave } else { $null }
        zip_exists = $false
        zip_size_bytes = $null
    }
    files = [ordered]@{
        report = $ReportPath
        zip = $ZipPath
        source = $PlanPath
        waves = @($waveFiles.ToArray())
    }
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$zipInputs.Insert(0, $ReportPath)

if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $ZipPath -Force
}

if ($zipInputs.Count -gt 0) {
    Compress-Archive -LiteralPath @($zipInputs.ToArray()) -DestinationPath $ZipPath -Force
}

$zipExists = Test-Path -LiteralPath $ZipPath -PathType Leaf
$report.summary.zip_exists = $zipExists
$report.summary.zip_size_bytes = if ($zipExists) { (Get-Item -LiteralPath $ZipPath).Length } else { $null }
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host "Legacy public executable remediation wave files written to $ReportPath"
Write-Host "Legacy public executable remediation wave ZIP written to $ZipPath"
