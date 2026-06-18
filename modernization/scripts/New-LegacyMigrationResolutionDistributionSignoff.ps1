param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-signoff.csv"),
    [string]$DistributionPackPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-distribution-pack.json")
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

function Get-SignoffKey($owner, $template, $csvPath) {
    return (([string]$owner).Trim().ToLowerInvariant() + '|' + ([string]$template).Trim().ToLowerInvariant() + '|' + ([string]$csvPath).Trim().ToLowerInvariant())
}

function Get-Field($row, $name, $default = '') {
    if ($null -eq $row) { return $default }
    if ($row.PSObject.Properties.Name -contains $name) { return $row.$name }
    return $default
}

function New-SignoffRow($item, $existingRow) {
    $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    return [pscustomobject][ordered]@{
        status = $status
        owner = $item.owner
        recipient = Get-Field $existingRow 'recipient'
        template = $item.template
        rows = $item.rows
        p1_rows = $item.p1_rows
        blocked_rows = $item.blocked_rows
        csv_path = $item.csv_path
        assignment = $item.assignment
        sent_at = Get-Field $existingRow 'sent_at'
        accepted_by = Get-Field $existingRow 'accepted_by'
        accepted_at = Get-Field $existingRow 'accepted_at'
        completed_by = Get-Field $existingRow 'completed_by'
        completed_at = Get-Field $existingRow 'completed_at'
        notes = Get-Field $existingRow 'notes'
    }
}

$distributionPack = Read-JsonReport $DistributionPackPath
$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = Get-SignoffKey (Get-Field $row 'owner') (Get-Field $row 'template') (Get-Field $row 'csv_path')
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'sent', 'accepted', 'completed', 'blocked')

if ($distributionPack -and $distributionPack.items) {
    foreach ($item in @($distributionPack.items)) {
        $key = Get-SignoffKey $item.owner $item.template $item.csv_path
        $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
        $row = New-SignoffRow $item $existingRow
        if ($validStatuses -notcontains $row.status) {
            $warnings.Add([pscustomobject][ordered]@{
                code = 'invalid_status'
                owner = $row.owner
                template = $row.template
                value = $row.status
                message = 'status must be pending, sent, accepted, completed, or blocked.'
            })
        }
        $rows.Add($row)
    }
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pendingItems = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$sentItems = @($rows.ToArray() | Where-Object { $_.status -eq 'sent' }).Count
$acceptedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'accepted' }).Count
$completedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'completed' }).Count
$blockedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet is a manual tracking template for distribution pack handoff. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if (-not $distributionPack) { 'missing' } elseif ($invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif ($completedItems -eq $rows.Count) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        pending_items = $pendingItems
        sent_items = $sentItems
        accepted_items = $acceptedItems
        completed_items = $completedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        row_work_items = if ($distributionPack) { $distributionPack.summary.row_work_items } else { 0 }
        p1_rows = if ($distributionPack) { $distributionPack.summary.p1_rows } else { 0 }
        blocked_rows = if ($distributionPack) { $distributionPack.summary.blocked_rows } else { 0 }
    }
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution distribution signoff written to $ReportPath"
Write-Host "Legacy migration resolution distribution signoff CSV written to $CsvPath"
