param(
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.md")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Wave($category) {
    switch ($category) {
        'uploaded_payload' { return 1 }
        'double_extension_payload' { return 1 }
        'editor_or_demo_handler' { return 2 }
        'static_path_script' { return 3 }
        'cross_language_sample' { return 3 }
        'legacy_public_admin' { return 4 }
        default { return 5 }
    }
}

function Get-WaveTitle($wave) {
    switch ($wave) {
        1 { return 'Quarantine uploaded or disguised executable payloads' }
        2 { return 'Disable editor and demo upload handlers' }
        3 { return 'Block script execution in static or cross-language paths' }
        4 { return 'Restrict legacy public admin scripts' }
        default { return 'Review remaining legacy public scripts' }
    }
}

function Get-WaveAcceptance($wave) {
    switch ($wave) {
        1 { return 'No uploaded or disguised executable payload remains web-executable.' }
        2 { return 'Editor, Uploadify, UEditor, KindEditor, and demo upload handlers are removed or blocked from public access.' }
        3 { return 'Static and cross-language directories cannot execute server-side scripts.' }
        4 { return 'Legacy admin scripts are IP/account restricted or removed from public exposure.' }
        default { return 'Remaining public scripts are documented as required read-only legacy access or removed.' }
    }
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

function Format-MarkdownText($value) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return '-' }
    return ([string]$value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

$worklist = Read-JsonReport $WorklistPath
$items = if ($worklist) { @($worklist.items) } else { @() }

$planRows = @($items | ForEach-Object {
    $wave = Get-Wave $_.category
    [pscustomobject][ordered]@{
        wave = $wave
        wave_title = Get-WaveTitle $wave
        item_id = $_.item_id
        category = $_.category
        severity = $_.severity
        status = $_.status
        owner = $_.owner
        relative_path = $_.relative_path
        recommended_action = $_.recommended_action
        acceptance = $_.acceptance
        evidence_ref = $_.evidence_ref
        notes = $_.notes
    }
} | Sort-Object wave, @{ Expression = { if ($_.severity -eq 'blocker') { 0 } else { 1 } } }, category, relative_path)

$waves = @($planRows | Group-Object wave | Sort-Object { [int]$_.Name } | ForEach-Object {
    $wave = [int]$_.Name
    $group = @($_.Group)
    [pscustomobject][ordered]@{
        wave = $wave
        title = Get-WaveTitle $wave
        status = if (@($group | Where-Object { $_.status -eq 'pending' }).Count -gt 0) { 'not_ready' } else { 'ready' }
        total_files = $group.Count
        blocker_files = @($group | Where-Object { $_.severity -eq 'blocker' }).Count
        warning_files = @($group | Where-Object { $_.severity -eq 'warning' }).Count
        pending_files = @($group | Where-Object { $_.status -eq 'pending' }).Count
        mitigated_files = @($group | Where-Object { $_.status -eq 'mitigated' }).Count
        accepted_with_risk_files = @($group | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
        blocked_files = @($group | Where-Object { $_.status -eq 'blocked' }).Count
        acceptance = Get-WaveAcceptance $wave
        categories = @($group | Group-Object category | Sort-Object Count -Descending | ForEach-Object {
            [pscustomobject][ordered]@{ category = $_.Name; count = $_.Count }
        })
        samples = @($group | Select-Object -First 10)
    }
})

$pendingFiles = @($planRows | Where-Object { $_.status -eq 'pending' }).Count
$blockerFiles = @($planRows | Where-Object { $_.severity -eq 'blocker' }).Count
$warningFiles = @($planRows | Where-Object { $_.severity -eq 'warning' }).Count
$nextWave = @($waves | Where-Object { $_.status -ne 'ready' } | Select-Object -First 1)

@($planRows) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Public Executable Remediation Plan'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines 'This plan is preview-only. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
Add-Line $lines
Add-Line $lines '## Summary'
Add-Line $lines
Add-Line $lines ('- Overall status: ' + $(if (-not $worklist) { 'missing' } elseif ($pendingFiles -gt 0) { 'not_ready' } else { 'ready' }))
Add-Line $lines ('- Total files: ' + $planRows.Count)
Add-Line $lines ('- Pending files: ' + $pendingFiles)
Add-Line $lines ('- Blocker files: ' + $blockerFiles)
Add-Line $lines ('- Warning files: ' + $warningFiles)
Add-Line $lines
Add-Line $lines '## Waves'
Add-Line $lines
Add-Line $lines '| Wave | Status | Files | Pending | Blockers | Warnings | Title | Acceptance |'
Add-Line $lines '| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |'
foreach ($wave in $waves) {
    Add-Line $lines "| $($wave.wave) | $($wave.status) | $($wave.total_files) | $($wave.pending_files) | $($wave.blocker_files) | $($wave.warning_files) | $(Format-MarkdownText $wave.title) | $(Format-MarkdownText $wave.acceptance) |"
}
Add-Line $lines
Add-Line $lines '## First Items'
Add-Line $lines
Add-Line $lines '| Wave | Severity | Status | Category | Relative Path | Action |'
Add-Line $lines '| ---: | --- | --- | --- | --- | --- |'
foreach ($row in @($planRows | Select-Object -First 30)) {
    Add-Line $lines "| $($row.wave) | $(Format-MarkdownText $row.severity) | $(Format-MarkdownText $row.status) | $(Format-MarkdownText $row.category) | $(Format-MarkdownText $row.relative_path) | $(Format-MarkdownText $row.recommended_action) |"
}
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This remediation plan groups public executable files into review waves. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $worklist) { 'missing' } elseif ($pendingFiles -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_files = $planRows.Count
        pending_files = $pendingFiles
        blocker_files = $blockerFiles
        warning_files = $warningFiles
        waves = $waves.Count
        ready_waves = @($waves | Where-Object { $_.status -eq 'ready' }).Count
        pending_waves = @($waves | Where-Object { $_.status -ne 'ready' }).Count
        next_wave = if ($nextWave.Count -gt 0) { $nextWave[0].wave } else { $null }
    }
    next_wave = if ($nextWave.Count -gt 0) { $nextWave[0] } else { $null }
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
        source = $WorklistPath
    }
    waves = @($waves)
    items = @($planRows)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation plan written to $ReportPath"
Write-Host "Legacy public executable remediation plan CSV written to $CsvPath"
Write-Host "Legacy public executable remediation plan Markdown written to $MarkdownPath"
