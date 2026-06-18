param(
    [string]$BatchPlanPath = (Join-Path $PSScriptRoot "legacy-migration-batch-plan.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-batch-db-dry-run.json")
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

function Get-BatchStatus($overallStatus) {
    if ($overallStatus -eq 'ready') { return 'ready' }
    if ($overallStatus -eq 'blocked') { return 'blocked' }
    return 'pending'
}

function Get-ItemStatus($stageStatus) {
    if ($stageStatus -eq 'ready') { return 'ready' }
    if ($stageStatus -eq 'blocked' -or $stageStatus -eq 'missing') { return 'blocked' }
    return 'pending'
}

$batchPlan = Read-JsonReport $BatchPlanPath
if (-not $batchPlan) { throw "Migration batch plan not found: $BatchPlanPath" }

$items = New-Object System.Collections.Generic.List[object]
$readyItemCount = 0
$pendingItemCount = 0
$blockedItemCount = 0
foreach ($stage in @($batchPlan.stages)) {
    $warnings = New-Object System.Collections.Generic.List[string]
    foreach ($warning in @($stage.warnings)) {
        if ($warning) { $warnings.Add([string]$warning) }
    }
    $status = Get-ItemStatus $stage.status
    if ($status -eq 'ready') { $readyItemCount++ }
    elseif ($status -eq 'blocked') { $blockedItemCount++ }
    else { $pendingItemCount++ }

    $items.Add([pscustomobject][ordered]@{
        legacy_table = $stage.key
        target_table = $stage.target
        status = $status
        create_found = $true
        insert_statement_count = 0
        estimated_row_count = Get-Number $stage.planned_count
        warning_count = $warnings.Count
        metadata = [ordered]@{
            order = Get-Number $stage.order
            label = $stage.label
            stage_status = $stage.status
            ready_count = Get-Number $stage.ready_count
            waiting_count = Get-Number $stage.waiting_count
            blocked_count = Get-Number $stage.blocked_count
            dependencies = @($stage.dependencies)
            warnings = @($warnings.ToArray())
        }
    })
}

$batch = [pscustomobject][ordered]@{
    name = 'legacy-core-migration-dry-run'
    mode = 'dry_run'
    source_path = $BatchPlanPath
    status = Get-BatchStatus $batchPlan.overall_status
    started_at = $null
    finished_at = $null
    summary = $batchPlan.summary
    metadata = [ordered]@{
        overall_status = $batchPlan.overall_status
        mock_validation = $batchPlan.mock_validation
        generated_from = 'legacy-migration-batch-plan.json'
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    batch_plan = $BatchPlanPath
    target_tables = @('migration_batches', 'migration_batch_items')
    summary = [ordered]@{
        batch_count = 1
        item_count = $items.Count
        ready_items = $readyItemCount
        pending_items = $pendingItemCount
        blocked_items = $blockedItemCount
    }
    batch = $batch
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration batch DB dry-run written to $ReportPath"
