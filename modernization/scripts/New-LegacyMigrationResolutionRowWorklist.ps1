param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-row-worklist.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-row-worklist.csv"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [int]$SampleSize = 30
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Test-PositiveInteger($value) {
    if (Test-Blank $value) { return $false }
    return [regex]::IsMatch([string]$value, '^[1-9][0-9]*$')
}

function Join-Fields($values) {
    return (@($values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ',')
}

function Add-RowItem($items, $template, $target, $rowNumber, $legacyId, $owner, $priority, $status, $missingFields, $invalidFields, $action, $context) {
    if ($status -eq 'ready') { return }
    $items.Add([pscustomobject][ordered]@{
        priority = $priority
        owner = $owner
        template = $template
        target = $target
        row_number = $rowNumber
        legacy_id = $legacyId
        status = $status
        missing_fields = @($missingFields)
        invalid_fields = @($invalidFields)
        action = $action
        context = $context
    })
}

function New-CsvRow($item) {
    return [pscustomobject][ordered]@{
        priority = $item.priority
        owner = $item.owner
        template = $item.template
        target = $item.target
        row_number = $item.row_number
        legacy_id = $item.legacy_id
        status = $item.status
        missing_fields = Join-Fields $item.missing_fields
        invalid_fields = Join-Fields $item.invalid_fields
        action = $item.action
        context = $item.context
    }
}

$items = New-Object System.Collections.Generic.List[object]
$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$rowNumber = 1
foreach ($row in @($unitRows)) {
    $rowNumber++
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]
    if (-not (Test-PositiveInteger $row.legacy_unit_id)) { $invalid.Add('legacy_unit_id') }
    if (Test-Blank $row.unit_id) { $missing.Add('unit_id') } elseif (-not (Test-PositiveInteger $row.unit_id)) { $invalid.Add('unit_id') }
    if (Test-Blank $row.owner_id) { $missing.Add('owner_id') } elseif (-not (Test-PositiveInteger $row.owner_id)) { $invalid.Add('owner_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.unit_id) -and (Test-Blank $row.owner_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }
    $owner = if (@($invalid.ToArray()).Count -gt 0) { 'data_operator' } elseif (@($missing.ToArray()) -contains 'unit_id' -or @($missing.ToArray()) -contains 'owner_id') { 'migration_engineer' } else { 'business_reviewer' }
    $priority = if ($status -eq 'blocked') { 'P1' } elseif ($owner -eq 'migration_engineer') { 'P2' } else { 'P3' }
    $action = if ($status -eq 'blocked') { 'Fix invalid or partially filled unit/user mapping row.' } elseif ($owner -eq 'migration_engineer') { 'Fill unit_id and owner_id, then ask business reviewer to approve.' } else { 'Review the mapped unit/user row and fill approved_by.' }
    $context = "project_count=$($row.project_count);status=$($row.status);unit_id=$($row.unit_id);owner_id=$($row.owner_id);approved_by=$($row.approved_by)"

    Add-RowItem $items 'legacy-unit-user-id-map.template.csv' 'unit_user_mapping' $rowNumber $row.legacy_unit_id $owner $priority $status @($missing.ToArray()) @($invalid.ToArray()) $action $context
}

$rowNumber = 1
foreach ($row in @($projectRows)) {
    $rowNumber++
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]
    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $invalid.Add('legacy_project_id') }
    if (Test-Blank $row.new_project_id) { $missing.Add('new_project_id') } elseif (-not (Test-PositiveInteger $row.new_project_id)) { $invalid.Add('new_project_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.new_project_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }
    $owner = if (@($invalid.ToArray()).Count -gt 0) { 'data_operator' } elseif (@($missing.ToArray()) -contains 'new_project_id') { 'migration_engineer' } else { 'business_reviewer' }
    $priority = if ($status -eq 'blocked') { 'P1' } elseif ($owner -eq 'migration_engineer') { 'P2' } else { 'P3' }
    $action = if ($status -eq 'blocked') { 'Fix invalid or partially filled project mapping row.' } elseif ($owner -eq 'migration_engineer') { 'Fill new_project_id, then ask business reviewer to approve.' } else { 'Review the mapped project row and fill approved_by.' }
    $context = "attachment_count=$($row.attachment_count);ready_attachment_count=$($row.ready_attachment_count);blocked_attachment_count=$($row.blocked_attachment_count);status=$($row.status);new_project_id=$($row.new_project_id);approved_by=$($row.approved_by)"

    Add-RowItem $items 'legacy-project-id-map.template.csv' 'project_mapping' $rowNumber $row.legacy_project_id $owner $priority $status @($missing.ToArray()) @($invalid.ToArray()) $action $context
}

$rowNumber = 1
foreach ($row in @($attachmentRows)) {
    $rowNumber++
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()
    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $invalid.Add('legacy_project_id') }
    if (Test-Blank $decision) { $missing.Add('decision') }
    elseif (@('recover', 'exception') -notcontains $decision) { $invalid.Add('decision') }
    elseif (($decision -eq 'recover') -and (Test-Blank $row.replacement_path)) { $missing.Add('replacement_path') }
    elseif (($decision -eq 'exception') -and (Test-Blank $row.exception_reason)) { $missing.Add('exception_reason') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.decision) -and (Test-Blank $row.replacement_path) -and (Test-Blank $row.exception_reason) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }
    $owner = if (@($invalid.ToArray()).Count -gt 0) { 'data_operator' } elseif (@($missing.ToArray()) -contains 'decision' -or @($missing.ToArray()) -contains 'approved_by') { 'business_reviewer' } else { 'data_operator' }
    $priority = if ($status -eq 'blocked') { 'P1' } elseif (@($missing.ToArray()) -contains 'decision') { 'P1' } elseif ($owner -eq 'data_operator') { 'P2' } else { 'P3' }
    $action = if ($status -eq 'blocked') { 'Fix invalid or partially filled attachment exception row.' } elseif (@($missing.ToArray()) -contains 'decision') { 'Choose recover or exception and fill approved_by.' } elseif ($owner -eq 'data_operator') { 'Fill replacement_path or exception_reason for the selected decision.' } else { 'Review the attachment exception row and fill approved_by.' }
    $context = "project=$($row.legacy_project_id);field=$($row.field);path=$($row.path);original_name=$($row.original_name);decision=$($row.decision);approved_by=$($row.approved_by)"

    Add-RowItem $items 'legacy-attachment-exceptions.template.csv' 'attachment_exception' $rowNumber $row.legacy_id $owner $priority $status @($missing.ToArray()) @($invalid.ToArray()) $action $context
}

$sortedItems = @($items.ToArray() | Sort-Object -Property priority, owner, template, row_number)
$byOwner = @($sortedItems | Group-Object owner | Sort-Object Name | ForEach-Object {
    [pscustomobject][ordered]@{
        owner = $_.Name
        rows = $_.Count
        p1_rows = @($_.Group | Where-Object { $_.priority -eq 'P1' }).Count
        blocked_rows = @($_.Group | Where-Object { $_.status -eq 'blocked' }).Count
    }
})

$byTemplate = @($sortedItems | Group-Object template | Sort-Object Name | ForEach-Object {
    [pscustomobject][ordered]@{
        template = $_.Name
        rows = $_.Count
        p1_rows = @($_.Group | Where-Object { $_.priority -eq 'P1' }).Count
        blocked_rows = @($_.Group | Where-Object { $_.status -eq 'blocked' }).Count
    }
})

$blockedRows = @($sortedItems | Where-Object { $_.status -eq 'blocked' }).Count
$p1Rows = @($sortedItems | Where-Object { $_.priority -eq 'P1' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report expands resolution template gaps into row-level work items. It does not edit templates, copy files, import records, or write database records.'
    overall_status = if ($blockedRows -gt 0) { 'blocked' } elseif ($sortedItems.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        row_work_items = $sortedItems.Count
        p1_rows = $p1Rows
        blocked_rows = $blockedRows
        owner_count = $byOwner.Count
        template_count = $byTemplate.Count
    }
    by_owner = @($byOwner)
    by_template = @($byTemplate)
    sample_rows = @($sortedItems | Select-Object -First $SampleSize)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
@($sortedItems | ForEach-Object { New-CsvRow $_ }) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation
Write-Host "Legacy migration resolution row worklist written to $ReportPath"
Write-Host "Legacy migration resolution row worklist CSV written to $CsvPath"
