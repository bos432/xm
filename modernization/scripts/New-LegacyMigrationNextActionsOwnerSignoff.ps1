param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-signoff.csv"),
    [string]$OwnerFilesPath = (Join-Path $PSScriptRoot "legacy-migration-next-actions.owner-files.json")
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

function Get-SignoffKey($owner, $slug) {
    return (([string]$owner).Trim().ToLowerInvariant() + '|' + ([string]$slug).Trim().ToLowerInvariant())
}

function New-SignoffRow($ownerFile, $existingRow) {
    $status = (Get-Field $existingRow 'status' 'pending').Trim().ToLowerInvariant()
    if (Test-Blank $status) { $status = 'pending' }

    return [pscustomobject][ordered]@{
        status = $status
        owner = $ownerFile.owner
        slug = $ownerFile.slug
        recipient = Get-Field $existingRow 'recipient'
        action_count = $ownerFile.count
        blockers = $ownerFile.blockers
        warnings = $ownerFile.warnings
        csv_path = $ownerFile.csv
        markdown_path = $ownerFile.markdown
        blocker_csv_path = $ownerFile.blocker_csv
        blocker_markdown_path = $ownerFile.blocker_markdown
        sent_at = Get-Field $existingRow 'sent_at'
        accepted_by = Get-Field $existingRow 'accepted_by'
        accepted_at = Get-Field $existingRow 'accepted_at'
        completed_by = Get-Field $existingRow 'completed_by'
        completed_at = Get-Field $existingRow 'completed_at'
        evidence_ref = Get-Field $existingRow 'evidence_ref'
        notes = Get-Field $existingRow 'notes'
    }
}

$ownerFilesReport = Read-JsonReport $OwnerFilesPath
$existingRows = Read-CsvRows $CsvPath
$existingByKey = @{}
foreach ($row in @($existingRows)) {
    $key = Get-SignoffKey (Get-Field $row 'owner') (Get-Field $row 'slug')
    if (-not [string]::IsNullOrWhiteSpace($key)) { $existingByKey[$key] = $row }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]
$validStatuses = @('pending', 'sent', 'accepted', 'completed', 'blocked')

if ($ownerFilesReport -and $ownerFilesReport.files) {
    foreach ($ownerFile in @($ownerFilesReport.files)) {
        $key = Get-SignoffKey $ownerFile.owner $ownerFile.slug
        $existingRow = if ($existingByKey.ContainsKey($key)) { $existingByKey[$key] } else { $null }
        $row = New-SignoffRow $ownerFile $existingRow
        if ($validStatuses -notcontains $row.status) {
            $warnings.Add([pscustomobject][ordered]@{
                code = 'invalid_status'
                owner = $row.owner
                slug = $row.slug
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
$ownersWithBlockers = @($rows.ToArray() | Where-Object { [int]$_.blockers -gt 0 }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This signoff sheet tracks owner-specific next-action handoff and receipt. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $ownerFilesReport) { 'missing' } elseif ($invalidItems -gt 0 -or $blockedItems -gt 0) { 'blocked' } elseif ($completedItems -eq $rows.Count) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        signoff_items = $rows.Count
        owners_with_blockers = $ownersWithBlockers
        pending_items = $pendingItems
        sent_items = $sentItems
        accepted_items = $acceptedItems
        completed_items = $completedItems
        blocked_items = $blockedItems
        invalid_items = $invalidItems
        owner_files = if ($ownerFilesReport) { $ownerFilesReport.owner_count } else { 0 }
    }
    owner_manifest = $OwnerFilesPath
    csv_path = $CsvPath
    warnings = @($warnings.ToArray())
    items = @($rows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration next actions owner signoff written to $ReportPath"
Write-Host "Legacy migration next actions owner signoff CSV written to $CsvPath"
