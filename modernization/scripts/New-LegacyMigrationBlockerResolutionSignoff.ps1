param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-signoff.csv"),
    [string]$ResolutionPackPath = (Join-Path $PSScriptRoot "legacy-migration-blocker-resolution-pack.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
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

function Get-SignoffKey($stage) {
    return ([string]$stage).Trim().ToLowerInvariant()
}

function Join-Values($values) {
    $items = @($values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return '-' }
    return ($items -join '; ')
}

function New-SignoffRow($item, $existingRow) {
    $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    return [pscustomobject][ordered]@{
        status = $status
        stage = $item.stage
        owner = $item.owner
        planned_count = $item.planned_count
        ready_count = $item.ready_count
        waiting_count = $item.waiting_count
        blocked_count = $item.blocked_count
        warnings = Join-Values $item.warnings
        evidence_reports = Join-Values $item.evidence_reports
        approved_by = Get-Field $existingRow 'approved_by'
        approved_at = Get-Field $existingRow 'approved_at'
        executed_by = Get-Field $existingRow 'executed_by'
        executed_at = Get-Field $existingRow 'executed_at'
        verified_by = Get-Field $existingRow 'verified_by'
        verified_at = Get-Field $existingRow 'verified_at'
        notes = Get-Field $existingRow 'notes'
    }
}

$resolutionPack = Read-JsonReport $ResolutionPackPath
$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = Get-SignoffKey (Get-Field $row 'stage')
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'approved', 'executed', 'verified', 'blocked')

if ($resolutionPack -and $resolutionPack.items) {
    foreach ($item in @($resolutionPack.items)) {
        $key = Get-SignoffKey $item.stage
        $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
        $row = New-SignoffRow $item $existingRow
        if ($validStatuses -notcontains $row.status) {
            $warnings.Add([pscustomobject][ordered]@{
                code = 'invalid_status'
                stage = $row.stage
                value = $row.status
                message = 'status must be pending, approved, executed, verified, or blocked.'
            })
        }
        $rows.Add($row)
    }
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pendingItems = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$approvedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'approved' }).Count
$executedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'executed' }).Count
$verifiedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'verified' }).Count
$blockedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks manual approval, execution, and verification for blocker resolution. It does not copy files, import records, update templates, or write database records.'
    overall_status = if (-not $resolutionPack) { 'missing' } elseif ($invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif ($verifiedItems -eq $rows.Count) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        pending_items = $pendingItems
        approved_items = $approvedItems
        executed_items = $executedItems
        verified_items = $verifiedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        blocked_stages = if ($resolutionPack) { $resolutionPack.summary.blocked_stages } else { 0 }
    }
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration blocker resolution signoff written to $ReportPath"
Write-Host "Legacy migration blocker resolution signoff CSV written to $CsvPath"
