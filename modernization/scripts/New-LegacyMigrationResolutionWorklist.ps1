param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.json"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [int]$SampleSize = 12
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

function New-Analysis($legacyId, $status, $missingFields, $invalidFields, $action) {
    return [pscustomobject][ordered]@{
        legacy_id = $legacyId
        status = $status
        missing_fields = @($missingFields)
        invalid_fields = @($invalidFields)
        action = $action
    }
}

function Get-UnitUserAnalysis($row) {
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]

    if (-not (Test-PositiveInteger $row.legacy_unit_id)) { $invalid.Add('legacy_unit_id') }
    if (Test-Blank $row.unit_id) { $missing.Add('unit_id') } elseif (-not (Test-PositiveInteger $row.unit_id)) { $invalid.Add('unit_id') }
    if (Test-Blank $row.owner_id) { $missing.Add('owner_id') } elseif (-not (Test-PositiveInteger $row.owner_id)) { $invalid.Add('owner_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.unit_id) -and (Test-Blank $row.owner_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }
    $action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Fill unit_id, owner_id, and approved_by.' } else { 'Fix invalid or partially filled unit/user mapping row.' }

    return New-Analysis $row.legacy_unit_id $status @($missing.ToArray()) @($invalid.ToArray()) $action
}

function Get-ProjectAnalysis($row) {
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]

    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $invalid.Add('legacy_project_id') }
    if (Test-Blank $row.new_project_id) { $missing.Add('new_project_id') } elseif (-not (Test-PositiveInteger $row.new_project_id)) { $invalid.Add('new_project_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.new_project_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }
    $action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Fill new_project_id and approved_by.' } else { 'Fix invalid or partially filled project mapping row.' }

    return New-Analysis $row.legacy_project_id $status @($missing.ToArray()) @($invalid.ToArray()) $action
}

function Get-AttachmentAnalysis($row) {
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
    $action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Choose recover or exception, fill the matching field, and add approved_by.' } else { 'Fix invalid or partially filled attachment exception row.' }

    return New-Analysis $row.legacy_id $status @($missing.ToArray()) @($invalid.ToArray()) $action
}

function Add-WorkItem($items, $template, $target, $priority, $owner, $fieldGroup, $status, $rowCount, $samples, $action, $acceptance) {
    if ($rowCount -le 0) { return }
    $items.Add([pscustomobject][ordered]@{
        template = $template
        target = $target
        priority = $priority
        owner = $owner
        field_group = $fieldGroup
        status = $status
        row_count = $rowCount
        sample_rows = @($samples)
        action = $action
        acceptance = $acceptance
    })
}

function New-SampleRow($rowNumber, $legacyId, $missingFields, $invalidFields) {
    return [pscustomobject][ordered]@{
        row_number = $rowNumber
        legacy_id = $legacyId
        missing_fields = @($missingFields)
        invalid_fields = @($invalidFields)
    }
}

function New-TemplateWorkItems($template, $target, $rows, $AnalyzeRow, $taskDefinitions) {
    $rowNumber = 1
    $readyRows = 0
    $pendingRows = 0
    $blockedRows = 0
    $definitions = @($taskDefinitions)
    foreach ($definition in $definitions) {
        $definition.row_count = 0
        $definition.samples = New-Object System.Collections.Generic.List[object]
    }

    foreach ($row in @($rows)) {
        $rowNumber++
        $analysis = & $AnalyzeRow $row
        if ($analysis.status -eq 'ready') { $readyRows++ }
        elseif ($analysis.status -eq 'pending') { $pendingRows++ }
        else { $blockedRows++ }

        foreach ($definition in $definitions) {
            $matches = $false
            if ($definition.kind -eq 'invalid') {
                $matches = @($analysis.invalid_fields).Count -gt 0
            } else {
                foreach ($field in @($definition.fields)) {
                    if (@($analysis.missing_fields) -contains $field) { $matches = $true }
                }
            }

            if ($matches) {
                $definition.row_count++
                if ($definition.samples.Count -lt $SampleSize) {
                    $definition.samples.Add((New-SampleRow $rowNumber $analysis.legacy_id @($analysis.missing_fields) @($analysis.invalid_fields)))
                }
            }
        }
    }

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $definitions) {
        Add-WorkItem $items $template $target $definition.priority $definition.owner $definition.field_group $definition.status $definition.row_count @($definition.samples.ToArray()) $definition.action $definition.acceptance
    }

    return [pscustomobject][ordered]@{
        summary = [ordered]@{
            total_rows = @($rows).Count
            ready_rows = $readyRows
            pending_rows = $pendingRows
            blocked_rows = $blockedRows
        }
        items = @($items.ToArray())
    }
}

function New-TaskDefinition($priority, $owner, $fieldGroup, $fields, $status, $action, $acceptance, $kind = 'missing') {
    return [pscustomobject]@{
        priority = $priority
        owner = $owner
        field_group = $fieldGroup
        fields = @($fields)
        status = $status
        action = $action
        acceptance = $acceptance
        kind = $kind
        row_count = 0
        samples = $null
    }
}

$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$unitWork = New-TemplateWorkItems 'legacy-unit-user-id-map.template.csv' 'unit_user_mapping' $unitRows ${function:Get-UnitUserAnalysis} @(
    (New-TaskDefinition 'P1' 'data_operator' 'invalid_values' @() 'blocked' 'Fix invalid legacy_unit_id, unit_id, or owner_id values.' 'No invalid id values remain in unit/user mapping CSV.' 'invalid')
    (New-TaskDefinition 'P2' 'migration_engineer' 'unit_id,owner_id' @('unit_id', 'owner_id') 'open' 'Create or locate the new unit and owner user, then fill unit_id and owner_id.' 'Each legacy unit row has positive unit_id and owner_id values.')
    (New-TaskDefinition 'P3' 'business_reviewer' 'approved_by' @('approved_by') 'open' 'Review the mapping result and fill approved_by.' 'Each mapped unit row has an approval operator.')
)

$projectWork = New-TemplateWorkItems 'legacy-project-id-map.template.csv' 'project_mapping' $projectRows ${function:Get-ProjectAnalysis} @(
    (New-TaskDefinition 'P1' 'data_operator' 'invalid_values' @() 'blocked' 'Fix invalid legacy_project_id or new_project_id values.' 'No invalid project id values remain in project mapping CSV.' 'invalid')
    (New-TaskDefinition 'P2' 'migration_engineer' 'new_project_id' @('new_project_id') 'open' 'Create or locate the new project record, then fill new_project_id.' 'Each legacy project row has a positive new_project_id value.')
    (New-TaskDefinition 'P3' 'business_reviewer' 'approved_by' @('approved_by') 'open' 'Review the project mapping result and fill approved_by.' 'Each mapped project row has an approval operator.')
)

$attachmentWork = New-TemplateWorkItems 'legacy-attachment-exceptions.template.csv' 'attachment_exception' $attachmentRows ${function:Get-AttachmentAnalysis} @(
    (New-TaskDefinition 'P1' 'data_operator' 'invalid_values' @() 'blocked' 'Fix invalid legacy_project_id or decision values.' 'No invalid attachment exception values remain in CSV.' 'invalid')
    (New-TaskDefinition 'P1' 'business_reviewer' 'decision' @('decision') 'open' 'Choose recover or exception for each missing attachment.' 'Each attachment exception row has a decision value of recover or exception.')
    (New-TaskDefinition 'P2' 'data_operator' 'replacement_or_reason' @('replacement_path', 'exception_reason') 'open' 'For recover, fill replacement_path. For exception, fill exception_reason.' 'Each decision has the matching replacement path or exception reason.')
    (New-TaskDefinition 'P3' 'business_reviewer' 'approved_by' @('approved_by') 'open' 'Review the attachment exception decision and fill approved_by.' 'Each attachment exception row has an approval operator.')
)

$allItems = @($unitWork.items + $projectWork.items + $attachmentWork.items)
$openItems = @($allItems | Where-Object { $_.row_count -gt 0 })
$blockedItems = @($openItems | Where-Object { $_.status -eq 'blocked' })
$p1Items = @($openItems | Where-Object { $_.priority -eq 'P1' })

$totalRows = $unitWork.summary.total_rows + $projectWork.summary.total_rows + $attachmentWork.summary.total_rows
$readyRows = $unitWork.summary.ready_rows + $projectWork.summary.ready_rows + $attachmentWork.summary.ready_rows
$pendingRows = $unitWork.summary.pending_rows + $projectWork.summary.pending_rows + $attachmentWork.summary.pending_rows
$blockedRows = $unitWork.summary.blocked_rows + $projectWork.summary.blocked_rows + $attachmentWork.summary.blocked_rows

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report turns operator CSV gaps into reviewable work items. It does not import records, copy files, or update CSV files.'
    overall_status = if ($blockedItems.Count -gt 0) { 'blocked' } elseif ($openItems.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        total_rows = $totalRows
        ready_rows = $readyRows
        pending_rows = $pendingRows
        blocked_rows = $blockedRows
        work_items = $openItems.Count
        p1_items = $p1Items.Count
        blocked_items = $blockedItems.Count
    }
    by_template = @(
        [ordered]@{ template = 'legacy-unit-user-id-map.template.csv'; target = 'unit_user_mapping'; summary = $unitWork.summary }
        [ordered]@{ template = 'legacy-project-id-map.template.csv'; target = 'project_mapping'; summary = $projectWork.summary }
        [ordered]@{ template = 'legacy-attachment-exceptions.template.csv'; target = 'attachment_exception'; summary = $attachmentWork.summary }
    )
    items = @($openItems | Sort-Object -Property priority, template, field_group)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution worklist written to $ReportPath"
