param(
    [string]$AttachmentDryRunPath = (Join-Path $PSScriptRoot "legacy-attachment-import-dry-run.json"),
    [string]$ProjectIdMapPath = (Join-Path $PSScriptRoot "legacy-project-id-map.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-project-file-db-dry-run.json"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

function Get-LegacyId($plan) {
    $source = Convert-EmptyToNull $plan.source_table
    $legacyId = Convert-EmptyToNull $plan.legacy_id
    $field = Convert-EmptyToNull $plan.field
    if (-not $source) { $source = 'legacy' }
    if (-not $legacyId) { $legacyId = 'unknown' }
    if (-not $field) { $field = 'file' }
    return '{0}:{1}:{2}' -f $source, $legacyId, $field
}

function Get-OriginalName($plan) {
    $originalName = Convert-EmptyToNull $plan.original_name
    if ($originalName) { return $originalName }
    $source = Convert-EmptyToNull $plan.source_path
    if ($source -and $source.Contains('|')) {
        $first = $source.Split('|')[0]
        if (Convert-EmptyToNull $first) { return $first }
    }
    $targetPath = Convert-EmptyToNull $plan.target_path
    if ($targetPath) { return [System.IO.Path]::GetFileName($targetPath) }
    return 'legacy-attachment'
}

if (-not (Test-Path -LiteralPath $AttachmentDryRunPath)) {
    throw "Attachment dry-run report not found: $AttachmentDryRunPath"
}

$dryRun = Get-Content -LiteralPath $AttachmentDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectIdMap = @{}
if (Test-Path -LiteralPath $ProjectIdMapPath) {
    $mapReport = Get-Content -LiteralPath $ProjectIdMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in @($mapReport.items)) {
        if (Convert-EmptyToNull $item.legacy_project_id) {
            $projectIdMap[[string]$item.legacy_project_id] = $item.new_project_id
        }
    }
}

$records = New-Object System.Collections.Generic.List[object]
$readySamples = New-Object System.Collections.Generic.List[object]
$blockedSamples = New-Object System.Collections.Generic.List[object]
$statusCounts = @{}
$purposeCounts = @{}
$readyCount = 0
$blockedCount = 0
$missingProjectMapCount = 0
$blockedByAttachmentCount = 0
$readyForImportCount = 0

foreach ($plan in @($dryRun.plans)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @($plan.warnings)) {
        if (Convert-EmptyToNull $warning) { $warnings.Add([string]$warning) }
    }

    $legacyProjectKey = if (Convert-EmptyToNull $plan.legacy_project_id) { [string]$plan.legacy_project_id } else { $null }
    $mappedProjectId = if ($legacyProjectKey -and $projectIdMap.ContainsKey($legacyProjectKey) -and (Convert-EmptyToNull $projectIdMap[$legacyProjectKey])) { [int64]$projectIdMap[$legacyProjectKey] } else { $null }

    $status = 'ready_for_import'
    if ($plan.dry_run_status -ne 'ready') {
        $status = 'blocked'
        $warnings.Add('attachment_not_ready')
        $blockedByAttachmentCount++
    } elseif (-not $mappedProjectId) {
        $status = 'ready_for_project_mapping'
        $warnings.Add('project_id_mapping_required')
        $missingProjectMapCount++
    } else {
        $readyForImportCount++
    }

    $purpose = if (Convert-EmptyToNull $plan.purpose) { [string]$plan.purpose } else { 'legacy_project_attachment' }
    $record = [pscustomobject][ordered]@{
        db_status = $status
        target_table = 'project_files'
        legacy_id = Get-LegacyId $plan
        project_id = $mappedProjectId
        legacy_project_id = $plan.legacy_project_id
        uploaded_by = $null
        disk = if (Convert-EmptyToNull $plan.target_disk) { $plan.target_disk } else { 'private' }
        path = $plan.target_path
        original_name = Get-OriginalName $plan
        mime_type = $null
        extension = if (Convert-EmptyToNull $plan.target_path) { ([System.IO.Path]::GetExtension([string]$plan.target_path)).TrimStart('.').ToLowerInvariant() } else { $null }
        size_bytes = if ($plan.source_size -ne $null) { [int64]$plan.source_size } else { 0 }
        sha256 = $null
        purpose = $purpose
        metadata = [ordered]@{
            legacy_source_table = $plan.source_table
            legacy_field = $plan.field
            legacy_source_path = $plan.source_path
            legacy_resolved_path = $plan.resolved_path
            attachment_dry_run_status = $plan.dry_run_status
            import_status = $plan.import_status
        }
        warnings = @($warnings.ToArray())
    }
    $records.Add($record)

    if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
    if (-not $purposeCounts.ContainsKey($purpose)) { $purposeCounts[$purpose] = 0 }
    $statusCounts[$status]++
    $purposeCounts[$purpose]++

    if ($status -eq 'blocked') {
        $blockedCount++
        if ($blockedSamples.Count -lt $SampleSize) { $blockedSamples.Add($record) }
    } else {
        $readyCount++
        if ($readySamples.Count -lt $SampleSize) { $readySamples.Add($record) }
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    attachment_dry_run = $AttachmentDryRunPath
    target_table = 'project_files'
    sample_size = $SampleSize
    summary = [ordered]@{
        total_records = $records.Count
        ready_for_import = $readyForImportCount
        ready_for_project_mapping = $readyCount - $readyForImportCount
        blocked_records = $blockedCount
        project_id_mapping_required = $missingProjectMapCount
        blocked_by_attachment = $blockedByAttachmentCount
    }
    by_status = @($statusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
    by_purpose = @($purposeCounts.GetEnumerator() | ForEach-Object { [ordered]@{ purpose = $_.Key; count = $_.Value } })
    samples = [ordered]@{
        blocked = @($blockedSamples.ToArray())
        ready = @($readySamples.ToArray())
    }
    records = @($records.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Project file DB dry-run written to $ReportPath"
