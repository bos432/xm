param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-signoff.csv")
)

$ErrorActionPreference = 'Stop'

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

function Get-SignoffKey($roleKey) {
    return ([string]$roleKey).Trim().ToLowerInvariant()
}

function New-Role($roleKey, $roleName, $confirmation, $evidence) {
    return [pscustomobject][ordered]@{
        role_key = $roleKey
        role_name = $roleName
        confirmation = $confirmation
        evidence = $evidence
    }
}

function New-SignoffRow($role, $existingRow) {
    $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    return [pscustomobject][ordered]@{
        status = $status
        role_key = $role.role_key
        role_name = $role.role_name
        owner = Get-Field $existingRow 'owner'
        confirmation = $role.confirmation
        evidence = $role.evidence
        signed_by = Get-Field $existingRow 'signed_by'
        signed_at = Get-Field $existingRow 'signed_at'
        notes = Get-Field $existingRow 'notes'
    }
}

$roles = @(
    New-Role 'technical_owner' 'Technical owner' 'Migration reports have no unaccepted blockers and dry-run outputs are reviewed.' 'legacy-migration-go-live-gate.json; legacy-migration-preflight-checklist.json'
    New-Role 'operations_owner' 'Operations owner' 'Backup, rollback, attachment copy window, and environment controls are ready.' 'legacy-migration-rollback-plan.md; legacy-migration-operator-runbook.md'
    New-Role 'business_owner' 'Business owner' 'Business sampling accepts unit, project, attachment, and workflow results.' 'legacy-migration-sampling-acceptance-signoff.json; legacy-migration-go-live-drill-report.md; legacy-migration-blocker-resolution-signoff.json'
    New-Role 'security_owner' 'Security owner' 'Upload, download authorization, legacy read-only boundary, and public directory exposure are accepted.' 'legacy-risk-report.txt; legacy-migration-preflight-checklist.json'
)

$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = Get-SignoffKey (Get-Field $row 'role_key')
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'signed', 'accepted_with_risk', 'rejected')

foreach ($role in @($roles)) {
    $key = Get-SignoffKey $role.role_key
    $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
    $row = New-SignoffRow $role $existingRow
    if ($validStatuses -notcontains $row.status) {
        $warnings.Add([pscustomobject][ordered]@{
            code = 'invalid_status'
            role_key = $row.role_key
            value = $row.status
            message = 'status must be pending, signed, accepted_with_risk, or rejected.'
        })
    }
    $rows.Add($row)
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$pendingItems = @($rows.ToArray() | Where-Object { $_.status -eq 'pending' }).Count
$signedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'signed' }).Count
$riskAcceptedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'accepted_with_risk' }).Count
$rejectedItems = @($rows.ToArray() | Where-Object { $_.status -eq 'rejected' }).Count
$invalidItems = @($rows.ToArray() | Where-Object { $validStatuses -notcontains $_.status }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks final role-level go-live acceptance. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($invalidItems -gt 0 -or $rejectedItems -gt 0) { 'blocked' } elseif (($signedItems + $riskAcceptedItems) -eq $rows.Count) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        pending_items = $pendingItems
        signed_items = $signedItems
        accepted_with_risk_items = $riskAcceptedItems
        rejected_items = $rejectedItems
        invalid_items = $invalidItems
    }
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live signoff written to $ReportPath"
Write-Host "Legacy migration go-live signoff CSV written to $CsvPath"
