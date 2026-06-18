param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-dry-run-comparison.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Number($value) {
    if ($null -eq $value) { return 0 }
    return [int64]$value
}

function New-Metric($total, $ready, $waiting, $blocked) {
    return [ordered]@{
        total = Get-Number $total
        ready = Get-Number $ready
        waiting = Get-Number $waiting
        blocked = Get-Number $blocked
    }
}

function New-ComparisonRow($target, $defaultMetric, $resolvedMetric, $mockMetric) {
    return [ordered]@{
        target = $target
        default = $defaultMetric
        resolved = $resolvedMetric
        mock = $mockMetric
        delta = [ordered]@{
            resolved_ready_vs_default = (Get-Number $resolvedMetric.ready) - (Get-Number $defaultMetric.ready)
            resolved_waiting_vs_default = (Get-Number $resolvedMetric.waiting) - (Get-Number $defaultMetric.waiting)
            resolved_blocked_vs_default = (Get-Number $resolvedMetric.blocked) - (Get-Number $defaultMetric.blocked)
            mock_ready_vs_default = (Get-Number $mockMetric.ready) - (Get-Number $defaultMetric.ready)
        }
    }
}

$unitDefault = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.json')
$unitResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.resolved.json')
$unitMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.mock.json')
$projectDefault = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$projectResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.resolved.json')
$projectMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.mock.json')
$fileDefault = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')
$fileResolved = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.resolved.json')
$fileMock = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.mock.json')

$rows = @(
    New-ComparisonRow 'unit_users' `
        (New-Metric $unitDefault.summary.total_users $unitDefault.summary.ready_users $unitDefault.summary.users_waiting_unit_mapping 0) `
        (New-Metric $unitResolved.summary.total_users $unitResolved.summary.ready_users $unitResolved.summary.users_waiting_unit_mapping 0) `
        (New-Metric $unitMock.summary.total_users $unitMock.summary.ready_users $unitMock.summary.users_waiting_unit_mapping 0)

    New-ComparisonRow 'projects' `
        (New-Metric $projectDefault.summary.total_records $projectDefault.summary.ready_for_import $projectDefault.summary.ready_for_unit_user_mapping 0) `
        (New-Metric $projectResolved.summary.total_records $projectResolved.summary.ready_for_import $projectResolved.summary.ready_for_unit_user_mapping 0) `
        (New-Metric $projectMock.summary.total_records $projectMock.summary.ready_for_import $projectMock.summary.ready_for_unit_user_mapping 0)

    New-ComparisonRow 'project_files' `
        (New-Metric $fileDefault.summary.total_records $fileDefault.summary.ready_for_import $fileDefault.summary.ready_for_project_mapping $fileDefault.summary.blocked_records) `
        (New-Metric $fileResolved.summary.total_records $fileResolved.summary.ready_for_import $fileResolved.summary.ready_for_project_mapping $fileResolved.summary.blocked_records) `
        (New-Metric $fileMock.summary.total_records $fileMock.summary.ready_for_import $fileMock.summary.ready_for_project_mapping $fileMock.summary.blocked_records)
)

$totalDefaultReady = 0
$totalResolvedReady = 0
$totalMockReady = 0
$totalResolvedWaiting = 0
$totalResolvedBlocked = 0
foreach ($row in @($rows)) {
    $totalDefaultReady += Get-Number $row.default.ready
    $totalResolvedReady += Get-Number $row.resolved.ready
    $totalMockReady += Get-Number $row.mock.ready
    $totalResolvedWaiting += Get-Number $row.resolved.waiting
    $totalResolvedBlocked += Get-Number $row.resolved.blocked
}

$missing = @()
foreach ($entry in @(
    @{ key = 'unit_default'; report = $unitDefault },
    @{ key = 'unit_resolved'; report = $unitResolved },
    @{ key = 'unit_mock'; report = $unitMock },
    @{ key = 'project_default'; report = $projectDefault },
    @{ key = 'project_resolved'; report = $projectResolved },
    @{ key = 'project_mock'; report = $projectMock },
    @{ key = 'project_file_default'; report = $fileDefault },
    @{ key = 'project_file_resolved'; report = $fileResolved },
    @{ key = 'project_file_mock'; report = $fileMock }
)) {
    if (-not $entry.report) { $missing += $entry.key }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'comparison_only'
    note = 'Compares default, operator resolved, and mock dry-run reports. It does not write database records or update source mapping reports.'
    overall_status = if (@($missing).Count -gt 0) { 'missing_inputs' } else { 'ready' }
    summary = [ordered]@{
        total_default_ready = $totalDefaultReady
        total_resolved_ready = $totalResolvedReady
        total_mock_ready = $totalMockReady
        resolved_ready_delta = $totalResolvedReady - $totalDefaultReady
        mock_ready_delta = $totalMockReady - $totalDefaultReady
        total_resolved_waiting = $totalResolvedWaiting
        total_resolved_blocked = $totalResolvedBlocked
        missing_inputs = @($missing).Count
    }
    missing_inputs = @($missing)
    rows = @($rows)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration dry-run comparison written to $ReportPath"
