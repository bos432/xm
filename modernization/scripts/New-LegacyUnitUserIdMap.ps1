param(
    [string]$ProjectDryRunPath = (Join-Path $PSScriptRoot "legacy-project-db-dry-run.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.json"),
    [int]$SampleSize = 20,
    [switch]$Mock,
    [int]$MockUnitStartId = 200000,
    [int]$MockUserStartId = 300000,
    [switch]$PreserveLegacyId
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

if (-not (Test-Path -LiteralPath $ProjectDryRunPath)) {
    throw "Project dry-run report not found: $ProjectDryRunPath"
}

$projectDryRun = Get-Content -LiteralPath $ProjectDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
$unitCounts = @{}
foreach ($record in @($projectDryRun.records)) {
    $legacyUnitId = Convert-EmptyToNull $record.legacy_unit_id
    if (-not $legacyUnitId) { continue }
    $key = [string]$legacyUnitId
    if (-not $unitCounts.ContainsKey($key)) { $unitCounts[$key] = 0 }
    $unitCounts[$key]++
}

$items = New-Object System.Collections.Generic.List[object]
$pendingSamples = New-Object System.Collections.Generic.List[object]
$mappedSamples = New-Object System.Collections.Generic.List[object]
$mappedUnits = 0
$pendingUnits = 0
$offset = 0

foreach ($entry in $unitCounts.GetEnumerator() | Sort-Object { [int]$_.Key }) {
    $legacyUnitId = [int]$entry.Key
    $unitId = $null
    $ownerId = $null
    $status = 'pending_unit_user_import'
    $warnings = @('unit_id_missing', 'owner_id_missing')

    if ($Mock) {
        $unitId = if ($PreserveLegacyId) { $legacyUnitId } else { $MockUnitStartId + $offset }
        $ownerId = if ($PreserveLegacyId) { $legacyUnitId } else { $MockUserStartId + $offset }
        $status = 'mock_mapped'
        $warnings = @('mock_unit_id', 'mock_owner_id')
        $mappedUnits++
    } else {
        $pendingUnits++
    }
    $offset++

    $item = [pscustomobject][ordered]@{
        legacy_unit_id = $legacyUnitId
        unit_id = $unitId
        owner_id = $ownerId
        status = $status
        project_count = $entry.Value
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
    project_dry_run = $ProjectDryRunPath
    sample_size = $SampleSize
    summary = [ordered]@{
        total_units = $items.Count
        mapped_units = $mappedUnits
        pending_units = $pendingUnits
        total_projects = @($projectDryRun.records).Count
    }
    samples = [ordered]@{
        pending = @($pendingSamples.ToArray())
        mapped = @($mappedSamples.ToArray())
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy unit/user id map written to $ReportPath"
