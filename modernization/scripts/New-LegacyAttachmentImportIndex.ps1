param(
    [string]$QualityReportPath = (Join-Path $PSScriptRoot "legacy-attachment-quality.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-import-index.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-attachment-import-index.csv")
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

function Get-ImportStatus($reference) {
    if (-not $reference.exists) { return 'blocked' }
    if (($reference.warnings | Where-Object { $_ -in @('dangerous_extension','path_traversal','absolute_or_url_path') }).Count -gt 0) { return 'blocked' }
    if (($reference.warnings | Where-Object { $_ -eq 'zero_byte_file' }).Count -gt 0) { return 'review' }
    return 'ready'
}

function Get-StoragePath($reference) {
    $projectId = Convert-EmptyToNull $reference.legacy_project_id
    $extension = Convert-EmptyToNull $reference.extension
    $legacyId = Convert-EmptyToNull $reference.legacy_id
    $field = Convert-EmptyToNull $reference.field
    $source = Convert-EmptyToNull $reference.source_table

    if (-not $projectId) { $projectId = 'unassigned' }
    if (-not $extension) { $extension = 'bin' }
    if (-not $legacyId) { $legacyId = 'unknown' }
    if (-not $field) { $field = 'file' }
    if (-not $source) { $source = 'legacy' }

    $safeLegacyId = ([string]$legacyId) -replace '[^A-Za-z0-9_-]', '_'
    $safeField = ([string]$field) -replace '[^A-Za-z0-9_-]', '_'
    $safeSource = ([string]$source) -replace '[^A-Za-z0-9_-]', '_'
    return "legacy/projects/$projectId/$safeSource-$safeLegacyId-$safeField.$extension"
}

if (-not (Test-Path -LiteralPath $QualityReportPath)) {
    throw "Attachment quality report not found: $QualityReportPath"
}

$quality = Get-Content -LiteralPath $QualityReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
$items = New-Object System.Collections.Generic.List[object]
$readySamples = New-Object System.Collections.Generic.List[object]
$reviewSamples = New-Object System.Collections.Generic.List[object]
$blockedSamples = New-Object System.Collections.Generic.List[object]
$statusCounts = @{}
$purposeCounts = @{}
$readyCount = 0
$reviewCount = 0
$blockedCount = 0
$missingCount = 0
$dangerousCount = 0

foreach ($reference in @($quality.references)) {
    $status = Get-ImportStatus $reference
    $purpose = if ($reference.source_table -eq 'pro_file') { 'legacy_review_attachment' } else { 'legacy_project_attachment' }
    $item = [pscustomobject][ordered]@{
        import_status = $status
        source_table = $reference.source_table
        legacy_id = $reference.legacy_id
        legacy_project_id = $reference.legacy_project_id
        field = $reference.field
        source_path = $reference.path
        raw_path = $reference.raw_path
        original_name = $reference.original_name
        extension = $reference.extension
        size = $reference.size
        resolved_path = $reference.resolved_path
        target_disk = 'private'
        target_path = Get-StoragePath $reference
        purpose = $purpose
        warnings = @($reference.warnings)
    }
    $items.Add($item)

    if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
    if (-not $purposeCounts.ContainsKey($purpose)) { $purposeCounts[$purpose] = 0 }
    $statusCounts[$status]++
    $purposeCounts[$purpose]++

    if ($status -eq 'ready') {
        $readyCount++
        if ($readySamples.Count -lt 20) { $readySamples.Add($item) }
    } elseif ($status -eq 'review') {
        $reviewCount++
        if ($reviewSamples.Count -lt 20) { $reviewSamples.Add($item) }
    } else {
        $blockedCount++
        if ($blockedSamples.Count -lt 20) { $blockedSamples.Add($item) }
    }

    if ($item.warnings -contains 'missing_file') { $missingCount++ }
    if ($item.warnings -contains 'dangerous_extension') { $dangerousCount++ }
}

$byStatus = @($statusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
$byPurpose = @($purposeCounts.GetEnumerator() | ForEach-Object { [ordered]@{ purpose = $_.Key; count = $_.Value } })
$itemArray = @($items.ToArray())
$readySampleArray = @($readySamples.ToArray())
$reviewSampleArray = @($reviewSamples.ToArray())
$blockedSampleArray = @($blockedSamples.ToArray())

$summary = [ordered]@{
    total_items = $items.Count
    ready_items = $readyCount
    review_items = $reviewCount
    blocked_items = $blockedCount
    missing_files = $missingCount
    dangerous_extensions = $dangerousCount
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    quality_report = $QualityReportPath
    target_disk = 'private'
    summary = $summary
    by_status = $byStatus
    by_purpose = $byPurpose
    samples = [ordered]@{
        blocked = $blockedSampleArray
        review = $reviewSampleArray
        ready = $readySampleArray
    }
    items = $itemArray
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$itemArray | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Attachment import index written to $ReportPath"
Write-Host "Attachment import CSV written to $CsvPath"
