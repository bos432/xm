param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$Root = (Resolve-Path "$PSScriptRoot\..\..").Path,
    [string]$RiskReportPath = (Join-Path $PSScriptRoot "legacy-risk-report.txt"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.csv"),
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.md")
)

$ErrorActionPreference = 'Stop'

function Read-RiskSection($path, $sectionName) {
    $items = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }

    $current = $false
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "[$sectionName]") {
            $current = $true
            continue
        }
        if ($current -and $trimmed.StartsWith('[')) { break }
        if ($current -and -not [string]::IsNullOrWhiteSpace($trimmed)) {
            $items.Add($trimmed)
        }
    }

    return @($items.ToArray())
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

function Get-RelativePath($path) {
    $value = [string]$path
    if ($value.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $value.Substring($Root.Length).TrimStart('\', '/')
    }
    return $value
}

function Get-Category($relativePath) {
    $path = ([string]$relativePath).Replace('\', '/').ToLowerInvariant()
    if ($path -match '(^|/)upload(s)?/' -or $path -match 'ueditor/.*/upload/') { return 'uploaded_payload' }
    if ($path -match 'uploadify|kindeditor|ueditor/.*/(action_|controller|upload|file_manager|demo)|/demo/') { return 'editor_or_demo_handler' }
    if ($path -match '^public/(admin|country|include|lib)/') { return 'legacy_public_admin' }
    if ($path -match '\.(asp|aspx|jsp|phps)$') { return 'cross_language_sample' }
    if ($path -match '\.(png|jpg|jpeg|gif|zip)\.php$') { return 'double_extension_payload' }
    if ($path -match '(^|/)(img|images|js|css|excel)/') { return 'static_path_script' }
    return 'legacy_public_script'
}

function Get-Severity($category) {
    if ($category -in @('uploaded_payload', 'double_extension_payload', 'cross_language_sample')) { return 'blocker' }
    if ($category -eq 'editor_or_demo_handler') { return 'blocker' }
    return 'warning'
}

function Get-RecommendedAction($category) {
    switch ($category) {
        'uploaded_payload' { return 'Quarantine the file outside the web root and confirm uploads cannot execute scripts.' }
        'double_extension_payload' { return 'Quarantine the disguised executable file and review adjacent uploads for compromise.' }
        'editor_or_demo_handler' { return 'Disable or remove editor/upload demo handlers from public access before go-live.' }
        'cross_language_sample' { return 'Remove cross-language sample handlers or block them at the web server.' }
        'legacy_public_admin' { return 'Restrict legacy public admin files by IP/account and block direct script execution where possible.' }
        'static_path_script' { return 'Block script execution in static directories and quarantine unexpected PHP files.' }
        default { return 'Confirm this script is required for read-only legacy access or move it outside public exposure.' }
    }
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

$paths = Read-RiskSection $RiskReportPath 'Executable files in public/upload roots'
$existingRows = Read-CsvRows $CsvPath
$existingByRelativePath = @{}
$existingByAbsolutePath = @{}

foreach ($row in @($existingRows)) {
    $relativeKey = Get-Key (Get-Field $row 'relative_path')
    if (-not (Test-Blank $relativeKey) -and -not $existingByRelativePath.ContainsKey($relativeKey)) {
        $existingByRelativePath[$relativeKey] = $row
    }

    $absoluteKey = Get-Key (Get-Field $row 'absolute_path')
    if (-not (Test-Blank $absoluteKey) -and -not $existingByAbsolutePath.ContainsKey($absoluteKey)) {
        $existingByAbsolutePath[$absoluteKey] = $row
    }
}

$rows = New-Object System.Collections.Generic.List[object]
$index = 0

foreach ($path in $paths) {
    $index++
    $relative = Get-RelativePath $path
    $category = Get-Category $relative
    $relativeKey = Get-Key $relative
    $absoluteKey = Get-Key $path
    $existingRow = if ($existingByRelativePath.ContainsKey($relativeKey)) {
        $existingByRelativePath[$relativeKey]
    } elseif ($existingByAbsolutePath.ContainsKey($absoluteKey)) {
        $existingByAbsolutePath[$absoluteKey]
    } else {
        $null
    }

    $status = Get-Field $existingRow 'status' 'pending'
    if (Test-Blank $status) { $status = 'pending' }
    $owner = Get-Field $existingRow 'owner' 'security_owner'
    if (Test-Blank $owner) { $owner = 'security_owner' }

    $rows.Add([pscustomobject][ordered]@{
        item_id = $index
        category = $category
        severity = Get-Severity $category
        status = $status
        relative_path = $relative
        absolute_path = $path
        recommended_action = Get-RecommendedAction $category
        acceptance = 'The file is not web-executable, is quarantined, or is explicitly approved for read-only legacy access with compensating controls.'
        owner = $owner
        evidence_ref = Get-Field $existingRow 'evidence_ref'
        notes = Get-Field $existingRow 'notes'
    })
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$categoryCounts = [ordered]@{}
$severityCounts = [ordered]@{}
foreach ($row in @($rows.ToArray())) {
    if (-not $categoryCounts.Contains($row.category)) { $categoryCounts[$row.category] = 0 }
    if (-not $severityCounts.Contains($row.severity)) { $severityCounts[$row.severity] = 0 }
    $categoryCounts[$row.category]++
    $severityCounts[$row.severity]++
}

$topCategories = @($categoryCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object {
    [pscustomobject][ordered]@{ category = $_.Key; count = $_.Value }
})

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Public Executable Worklist'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines 'This worklist is preview-only. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
Add-Line $lines
Add-Line $lines '## Summary'
Add-Line $lines
Add-Line $lines ('- Total files: ' + $rows.Count)
Add-Line $lines ('- Blockers: ' + $(if ($severityCounts.Contains('blocker')) { $severityCounts['blocker'] } else { 0 }))
Add-Line $lines ('- Warnings: ' + $(if ($severityCounts.Contains('warning')) { $severityCounts['warning'] } else { 0 }))
Add-Line $lines
Add-Line $lines '## Top Categories'
Add-Line $lines
Add-Line $lines '| Category | Count |'
Add-Line $lines '| --- | ---: |'
foreach ($category in $topCategories) {
    Add-Line $lines "| $($category.category) | $($category.count) |"
}
Add-Line $lines
Add-Line $lines '## First Items'
Add-Line $lines
Add-Line $lines '| ID | Severity | Category | Relative Path | Recommended Action |'
Add-Line $lines '| ---: | --- | --- | --- | --- |'
foreach ($row in @($rows.ToArray() | Select-Object -First 20)) {
    Add-Line $lines "| $($row.item_id) | $($row.severity) | $($row.category) | $($row.relative_path) | $($row.recommended_action) |"
}
$lines | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This worklist summarizes executable files found in public/upload roots. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if ($rows.Count -gt 0) { 'blocked' } else { 'ready' }
    summary = [ordered]@{
        total_files = $rows.Count
        blocker_files = if ($severityCounts.Contains('blocker')) { $severityCounts['blocker'] } else { 0 }
        warning_files = if ($severityCounts.Contains('warning')) { $severityCounts['warning'] } else { 0 }
        category_counts = $categoryCounts
        severity_counts = $severityCounts
    }
    files = [ordered]@{
        json = $ReportPath
        csv = $CsvPath
        markdown = $MarkdownPath
        source = $RiskReportPath
    }
    top_categories = @($topCategories)
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable worklist written to $ReportPath"
Write-Host "Legacy public executable worklist CSV written to $CsvPath"
Write-Host "Legacy public executable worklist Markdown written to $MarkdownPath"

