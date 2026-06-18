param(
    [string]$AttachmentDryRunPath = (Join-Path $PSScriptRoot "legacy-attachment-import-dry-run.json"),
    [string]$ProjectDryRunPath = (Join-Path $PSScriptRoot "legacy-project-db-dry-run.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-project-id-map.json"),
    [int]$SampleSize = 20,
    [switch]$Mock,
    [int]$MockStartId = 100000,
    [switch]$PreserveLegacyId
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

if (-not (Test-Path -LiteralPath $AttachmentDryRunPath)) {
    throw "Attachment dry-run report not found: $AttachmentDryRunPath"
}
if (-not (Test-Path -LiteralPath $ProjectDryRunPath)) {
    throw "Project dry-run report not found: $ProjectDryRunPath"
}

$dryRun = Get-Content -LiteralPath $AttachmentDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectDryRun = Get-Content -LiteralPath $ProjectDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectCounts = @{}
$readyCounts = @{}
$blockedCounts = @{}
$projectTitles = @{}
$projectStatuses = @{}

foreach ($record in @($projectDryRun.records)) {
    $legacyProjectId = Convert-EmptyToNull $record.legacy_id
    if (-not $legacyProjectId) { continue }
    $key = [string]$legacyProjectId
    if (-not $projectCounts.ContainsKey($key)) { $projectCounts[$key] = 0 }
    if (-not $readyCounts.ContainsKey($key)) { $readyCounts[$key] = 0 }
    if (-not $blockedCounts.ContainsKey($key)) { $blockedCounts[$key] = 0 }
    $projectTitles[$key] = $record.title
    $projectStatuses[$key] = $record.db_status
}

foreach ($plan in @($dryRun.plans)) {
    $legacyProjectId = Convert-EmptyToNull $plan.legacy_project_id
    if (-not $legacyProjectId) { continue }
    $key = [string]$legacyProjectId
    if (-not $projectCounts.ContainsKey($key)) { $projectCounts[$key] = 0 }
    if (-not $readyCounts.ContainsKey($key)) { $readyCounts[$key] = 0 }
    if (-not $blockedCounts.ContainsKey($key)) { $blockedCounts[$key] = 0 }
    $projectCounts[$key]++
    if ($plan.dry_run_status -eq 'ready') {
        $readyCounts[$key]++
    } else {
        $blockedCounts[$key]++
    }
}

$items = New-Object System.Collections.Generic.List[object]
$pendingSamples = New-Object System.Collections.Generic.List[object]
$mappedSamples = New-Object System.Collections.Generic.List[object]
$mappedProjects = 0
$pendingProjects = 0
$mockOffset = 0
foreach ($entry in $projectCounts.GetEnumerator() | Sort-Object { [int]$_.Key }) {
    $legacyProjectId = [int]$entry.Key
    $newProjectId = $null
    $status = 'pending_project_import'
    $warnings = @('new_project_id_missing')

    if ($Mock) {
        $newProjectId = if ($PreserveLegacyId) { $legacyProjectId } else { $MockStartId + $mockOffset }
        $mockOffset++
        $status = 'mock_mapped'
        $warnings = @('mock_project_id')
        $mappedProjects++
    } else {
        $pendingProjects++
    }

    $item = [pscustomobject][ordered]@{
        legacy_project_id = $legacyProjectId
        new_project_id = $newProjectId
        status = $status
        project_title = if ($projectTitles.ContainsKey($entry.Key)) { $projectTitles[$entry.Key] } else { $null }
        project_db_status = if ($projectStatuses.ContainsKey($entry.Key)) { $projectStatuses[$entry.Key] } else { $null }
        attachment_count = $entry.Value
        ready_attachment_count = $readyCounts[$entry.Key]
        blocked_attachment_count = $blockedCounts[$entry.Key]
        warnings = $warnings
    }
    $items.Add($item)
    if ($status -eq 'mock_mapped') {
        if ($mappedSamples.Count -lt $SampleSize) { $mappedSamples.Add($item) }
    } else {
        if ($pendingSamples.Count -lt $SampleSize) { $pendingSamples.Add($item) }
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = if ($Mock) { 'mock' } else { 'pending' }
    attachment_dry_run = $AttachmentDryRunPath
    project_dry_run = $ProjectDryRunPath
    sample_size = $SampleSize
    summary = [ordered]@{
        total_projects = $items.Count
        mapped_projects = $mappedProjects
        pending_projects = $pendingProjects
        total_attachments = @($dryRun.plans).Count
    }
    samples = [ordered]@{
        pending = @($pendingSamples.ToArray())
        mapped = @($mappedSamples.ToArray())
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy project id map written to $ReportPath"
