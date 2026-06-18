param(
    [string]$IndexPath = (Join-Path $PSScriptRoot "legacy-attachment-import-index.json"),
    [string]$TargetRoot = (Join-Path $PSScriptRoot "..\backend\storage\app\private"),
    [string]$ReportPath = '',
    [int]$SampleSize = 20,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

function Test-PathUnderRoot($path, $root) {
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $fullRoot = [System.IO.Path]::GetFullPath($root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $fullPath.StartsWith($fullRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

if (-not (Test-Path -LiteralPath $IndexPath)) {
    throw "Attachment import index not found: $IndexPath"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = if ($Execute) {
        Join-Path $PSScriptRoot "legacy-attachment-import-execute.json"
    } else {
        Join-Path $PSScriptRoot "legacy-attachment-import-dry-run.json"
    }
}

$index = Get-Content -LiteralPath $IndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
$targetRootFull = [System.IO.Path]::GetFullPath($TargetRoot)
$targetPathCounts = @{}

foreach ($item in @($index.items)) {
    $targetPath = Convert-EmptyToNull $item.target_path
    if (-not $targetPath) { continue }
    if (-not $targetPathCounts.ContainsKey([string]$targetPath)) { $targetPathCounts[[string]$targetPath] = 0 }
    $targetPathCounts[[string]$targetPath]++
}

$plans = New-Object System.Collections.Generic.List[object]
$readySamples = New-Object System.Collections.Generic.List[object]
$blockedSamples = New-Object System.Collections.Generic.List[object]
$reviewSamples = New-Object System.Collections.Generic.List[object]
$statusCounts = @{}
$readyCount = 0
$blockedCount = 0
$reviewCount = 0
$sourceMissingCount = 0
$targetExistsCount = 0
$targetDuplicateCount = 0
$targetEscapeCount = 0
$wouldCopyBytes = [int64]0
$copiedCount = 0
$copyFailedCount = 0
$skippedCount = 0
$copiedBytes = [int64]0

foreach ($item in @($index.items)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @($item.warnings)) {
        if (Convert-EmptyToNull $warning) { $warnings.Add([string]$warning) }
    }

    $sourcePath = Convert-EmptyToNull $item.resolved_path
    $targetPath = Convert-EmptyToNull $item.target_path
    $sourceExists = $false
    $sourceSize = $null
    $targetFullPath = $null
    $targetExists = $false
    $targetUnderRoot = $false

    if ($sourcePath -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $sourceFile = Get-Item -LiteralPath $sourcePath
        $sourceExists = $true
        $sourceSize = $sourceFile.Length
    } else {
        $warnings.Add('source_missing_at_dry_run')
        $sourceMissingCount++
    }

    if ($targetPath) {
        $targetFullPath = [System.IO.Path]::GetFullPath((Join-Path $targetRootFull $targetPath))
        $targetUnderRoot = Test-PathUnderRoot $targetFullPath $targetRootFull
        if (-not $targetUnderRoot) {
            $warnings.Add('target_path_escapes_root')
            $targetEscapeCount++
        }
        if (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
            $warnings.Add('target_file_exists')
            $targetExists = $true
            $targetExistsCount++
        }
        if ($targetPathCounts[[string]$targetPath] -gt 1) {
            $warnings.Add('duplicate_target_path')
            $targetDuplicateCount++
        }
    } else {
        $warnings.Add('target_path_missing')
    }

    $status = 'ready'
    if ($item.import_status -eq 'blocked' -or $warnings.Contains('source_missing_at_dry_run') -or $warnings.Contains('target_path_escapes_root') -or $warnings.Contains('duplicate_target_path')) {
        $status = 'blocked'
    } elseif ($item.import_status -eq 'review' -or $warnings.Contains('target_file_exists')) {
        $status = 'review'
    }

    if ($status -eq 'ready' -and $sourceSize) { $wouldCopyBytes += [int64]$sourceSize }

    $copyStatus = if ($Execute) { 'pending' } else { 'would_copy' }
    $copyError = $null
    if ($status -ne 'ready') {
        $copyStatus = 'skipped'
        if ($Execute) { $skippedCount++ }
    } elseif ($Execute) {
        try {
            $targetDirectory = Split-Path -Parent $targetFullPath
            if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $targetFullPath -Force:$false
            $copiedFile = Get-Item -LiteralPath $targetFullPath
            if ($sourceSize -ne $null -and $copiedFile.Length -ne $sourceSize) {
                throw "Copied size mismatch: source=$sourceSize target=$($copiedFile.Length)"
            }
            $copyStatus = 'copied'
            $copiedCount++
            if ($sourceSize) { $copiedBytes += [int64]$sourceSize }
        } catch {
            $copyStatus = 'failed'
            $copyError = $_.Exception.Message
            $copyFailedCount++
            $warnings.Add('copy_failed')
        }
    }

    $plan = [pscustomobject][ordered]@{
        dry_run_status = $status
        import_status = $item.import_status
        legacy_project_id = $item.legacy_project_id
        legacy_id = $item.legacy_id
        source_table = $item.source_table
        field = $item.field
        source_path = $item.source_path
        raw_path = $item.raw_path
        original_name = $item.original_name
        extension = $item.extension
        resolved_path = $sourcePath
        source_exists = $sourceExists
        source_size = $sourceSize
        target_disk = $item.target_disk
        target_path = $targetPath
        target_full_path = $targetFullPath
        target_under_root = $targetUnderRoot
        target_exists = $targetExists
        purpose = $item.purpose
        copy_status = $copyStatus
        copy_error = $copyError
        warnings = @($warnings.ToArray())
    }
    $plans.Add($plan)

    if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
    $statusCounts[$status]++
    if ($status -eq 'ready') {
        $readyCount++
        if ($readySamples.Count -lt $SampleSize) { $readySamples.Add($plan) }
    } elseif ($status -eq 'review') {
        $reviewCount++
        if ($reviewSamples.Count -lt $SampleSize) { $reviewSamples.Add($plan) }
    } else {
        $blockedCount++
        if ($blockedSamples.Count -lt $SampleSize) { $blockedSamples.Add($plan) }
    }
}

$byStatus = @($statusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
$planArray = @($plans.ToArray())

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = if ($Execute) { 'execute' } else { 'dry_run' }
    index_path = $IndexPath
    target_root = $targetRootFull
    sample_size = $SampleSize
    summary = [ordered]@{
        total_items = $plans.Count
        ready_items = $readyCount
        review_items = $reviewCount
        blocked_items = $blockedCount
        source_missing = $sourceMissingCount
        target_exists = $targetExistsCount
        duplicate_target_paths = $targetDuplicateCount
        target_path_escapes_root = $targetEscapeCount
        would_copy_bytes = $wouldCopyBytes
        copied_items = $copiedCount
        copied_bytes = $copiedBytes
        copy_failed_items = $copyFailedCount
        skipped_items = $skippedCount
    }
    by_status = $byStatus
    samples = [ordered]@{
        blocked = @($blockedSamples.ToArray())
        review = @($reviewSamples.ToArray())
        ready = @($readySamples.ToArray())
    }
    plans = $planArray
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Attachment import $($report.mode) report written to $ReportPath"
