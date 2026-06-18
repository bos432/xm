param(
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-security-baseline-operator-pack.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-baseline-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-baseline-signoff.csv")
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

function Get-Key($value) {
    return ([string]$value).Trim().ToLowerInvariant()
}

function New-SignoffRow($step, $existingRow) {
    $status = (Get-Field $existingRow 'status' $(if ($step.status -eq 'ready') { 'mitigated' } else { 'pending' })).Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = if ($step.status -eq 'ready') { 'mitigated' } else { 'pending' } }

    return [pscustomobject][ordered]@{
        status = $status
        step_key = ('security_' + $step.order)
        step_order = $step.order
        category = $step.category
        title = $step.title
        severity = $step.severity
        source_status = $step.status
        required_action = $step.action
        acceptance = $step.acceptance
        source = $step.source
        owner = Get-Field $existingRow 'owner'
        resolved_by = Get-Field $existingRow 'resolved_by'
        resolved_at = Get-Field $existingRow 'resolved_at'
        evidence_ref = Get-Field $existingRow 'evidence_ref'
        notes = Get-Field $existingRow 'notes'
    }
}

$operatorPack = Read-JsonReport $OperatorPackPath
$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = Get-Key (Get-Field $row 'step_key')
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'mitigated', 'accepted_with_risk', 'blocked')

if ($operatorPack -and $operatorPack.steps) {
    foreach ($step in @($operatorPack.steps)) {
        $key = Get-Key ('security_' + $step.order)
        $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
        $row = New-SignoffRow $step $existingRow
        if ($validStatuses -notcontains $row.status) {
            $warnings.Add([pscustomobject][ordered]@{
                code = 'invalid_status'
                step_key = $row.step_key
                value = $row.status
                message = 'status must be pending, mitigated, accepted_with_risk, or blocked.'
            })
        }
        $rows.Add($row)
    }
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pendingItems = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$mitigatedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'mitigated' }).Count
$riskAcceptedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$blockedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'blocked' }).Count
$invalidItems = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks security baseline mitigation and risk acceptance. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif (($mitigatedItems + $riskAcceptedItems) -eq $rows.Count -and $rows.Count -gt 0) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        pending_items = $pendingItems
        mitigated_items = $mitigatedItems
        accepted_with_risk_items = $riskAcceptedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        source_operator_status = if ($operatorPack) { $operatorPack.overall_status } else { 'missing' }
    }
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy security baseline signoff written to $ReportPath"
Write-Host "Legacy security baseline signoff CSV written to $CsvPath"