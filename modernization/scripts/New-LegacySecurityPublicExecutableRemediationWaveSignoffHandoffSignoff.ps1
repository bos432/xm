param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv"),
    [string]$HandoffPackPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json"),
    [string]$HandoffValidationPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json")
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

$handoffPack = Read-JsonReport $HandoffPackPath
$handoffValidation = Read-JsonReport $HandoffValidationPath
$existingRows = Read-CsvRows $CsvPath
$existingRow = if ($existingRows.Count -gt 0) { $existingRows[0] } else { $null }
$validStatuses = @('pending', 'delivered', 'accepted', 'accepted_with_risk', 'blocked')

$status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
if (Test-Blank $status) { $status = 'pending' }

$row = [pscustomobject][ordered]@{
    status = $status
    signoff_key = 'public_executable_wave_signoff_handoff'
    owner = Get-Field $existingRow 'owner' 'security_owner'
    recipient = Get-Field $existingRow 'recipient'
    package_file = if ($handoffPack) { $handoffPack.files.zip } else { Join-Path $PSScriptRoot 'legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip' }
    package_status = if ($handoffPack) { $handoffPack.overall_status } else { 'missing' }
    package_validation_status = if ($handoffValidation) { $handoffValidation.overall_status } else { 'missing' }
    handoff_files = if ($handoffPack) { $handoffPack.summary.handoff_files } else { 0 }
    missing_required = if ($handoffPack) { $handoffPack.summary.missing_required } else { 0 }
    sent_at = Get-Field $existingRow 'sent_at'
    accepted_by = Get-Field $existingRow 'accepted_by'
    accepted_at = Get-Field $existingRow 'accepted_at'
    evidence_ref = Get-Field $existingRow 'evidence_ref'
    notes = Get-Field $existingRow 'notes'
}

@($row) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

$invalidItems = if ($validStatuses -notcontains $row.status) { 1 } else { 0 }
$pendingItems = if ($row.status -eq 'pending') { 1 } else { 0 }
$deliveredItems = if ($row.status -eq 'delivered') { 1 } else { 0 }
$acceptedItems = if ($row.status -eq 'accepted') { 1 } else { 0 }
$riskItems = if ($row.status -eq 'accepted_with_risk') { 1 } else { 0 }
$blockedItems = if ($row.status -eq 'blocked') { 1 } else { 0 }

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks receipt and acceptance of the public executable remediation wave signoff handoff ZIP. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $handoffPack -or $invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif ($acceptedItems + $riskItems -eq 1) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = 1
        pending_items = $pendingItems
        delivered_items = $deliveredItems
        accepted_items = $acceptedItems
        accepted_with_risk_items = $riskItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        package_status = if ($handoffPack) { $handoffPack.overall_status } else { 'missing' }
        package_validation_status = if ($handoffValidation) { $handoffValidation.overall_status } else { 'missing' }
        package_missing_required = if ($handoffPack) { $handoffPack.summary.missing_required } else { 0 }
        package_zip_exists = if ($handoffPack) { $handoffPack.summary.zip_exists } else { $false }
    }
    csv_path = $CsvPath
    items = @($row)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation wave signoff handoff signoff written to $ReportPath"
Write-Host "Legacy public executable remediation wave signoff handoff signoff CSV written to $CsvPath"
