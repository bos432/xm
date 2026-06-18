param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-templates.json"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [switch]$Force
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

function Get-List($values) {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($value in @($values)) {
        if ($null -ne $value) { $items.Add($value) }
    }
    return @($items.ToArray())
}

function Convert-ToCsvValue($value) {
    if ($null -eq $value) { return '' }
    $text = [string]$value
    if ($text.Contains('"')) { $text = $text.Replace('"', '""') }
    if ($text.Contains(',') -or $text.Contains('"') -or $text.Contains("`r") -or $text.Contains("`n")) {
        return '"' + $text + '"'
    }
    return $text
}

$script:TemplateWriteResults = @{}

function Write-CsvRows($key, $path, $headers, $rows) {
    $existed = Test-Path -LiteralPath $path -PathType Leaf
    if ($existed -and -not $Force) {
        $script:TemplateWriteResults[$key] = 'preserved'
        return
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(($headers -join ','))
    foreach ($row in @($rows)) {
        $values = New-Object System.Collections.Generic.List[string]
        foreach ($header in $headers) {
            $values.Add((Convert-ToCsvValue $row[$header]))
        }
        $lines.Add(($values.ToArray() -join ','))
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    $script:TemplateWriteResults[$key] = if ($existed) { 'overwritten' } else { 'created' }
}

function Merge-CsvRows($key, $path, $headers, $rows, $keyField) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-CsvRows $key $path $headers $rows
        return
    }

    if ($Force) {
        Write-CsvRows $key $path $headers $rows
        return
    }

    $existingRows = @(Import-Csv -LiteralPath $path -Encoding UTF8)
    $existingByKey = @{}
    foreach ($row in @($existingRows)) {
        $rowKey = [string]$row.$keyField
        if (-not [string]::IsNullOrWhiteSpace($rowKey)) { $existingByKey[$rowKey] = $row }
    }

    $mergedRows = New-Object System.Collections.Generic.List[hashtable]
    foreach ($sourceRow in @($rows)) {
        $rowKey = [string]$sourceRow[$keyField]
        $existingRow = if ($existingByKey.ContainsKey($rowKey)) { $existingByKey[$rowKey] } else { $null }
        $merged = @{}
        foreach ($header in $headers) {
            if ($existingRow -and ($existingRow.PSObject.Properties.Name -contains $header) -and -not [string]::IsNullOrWhiteSpace([string]$existingRow.$header)) {
                $merged[$header] = $existingRow.$header
            } else {
                $merged[$header] = $sourceRow[$header]
            }
        }
        $mergedRows.Add($merged)
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(($headers -join ','))
    foreach ($row in @($mergedRows.ToArray())) {
        $values = New-Object System.Collections.Generic.List[string]
        foreach ($header in $headers) {
            $values.Add((Convert-ToCsvValue $row[$header]))
        }
        $lines.Add(($values.ToArray() -join ','))
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    $script:TemplateWriteResults[$key] = 'merged_preserved'
}

function New-TemplateArtifact($key, $path, $rows, $requiredColumns, $purpose, $writeStatus) {
    $exists = Test-Path -LiteralPath $path
    return [ordered]@{
        key = $key
        path = $path
        purpose = $purpose
        rows = @($rows).Count
        required_columns = @($requiredColumns)
        exists = $exists
        updated_at = if ($exists) { (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') } else { $null }
        size_bytes = if ($exists) { (Get-Item -LiteralPath $path).Length } else { $null }
        write_status = $writeStatus
    }
}

$unitUserMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-id-map.json')
$projectIdMap = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-id-map.json')
$attachmentQuality = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-quality.json')
$actionSheet = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-blocker-action-sheet.json')

$unitRows = New-Object System.Collections.Generic.List[hashtable]
foreach ($item in @(if ($unitUserMap.items) { Get-List $unitUserMap.items } else { Get-List $unitUserMap.samples.pending })) {
    $unitRows.Add(@{
        legacy_unit_id = $item.legacy_unit_id
        unit_id = ''
        owner_id = ''
        project_count = $item.project_count
        status = $item.status
        resolution_note = ''
        approved_by = ''
    })
}

$projectRows = New-Object System.Collections.Generic.List[hashtable]
foreach ($item in @(if ($projectIdMap.items) { Get-List $projectIdMap.items } else { Get-List $projectIdMap.samples.pending })) {
    $projectRows.Add(@{
        legacy_project_id = $item.legacy_project_id
        new_project_id = ''
        project_title = $item.project_title
        project_db_status = $item.project_db_status
        attachment_count = $item.attachment_count
        ready_attachment_count = $item.ready_attachment_count
        blocked_attachment_count = $item.blocked_attachment_count
        status = $item.status
        resolution_note = ''
        approved_by = ''
    })
}

$attachmentRows = New-Object System.Collections.Generic.List[hashtable]
foreach ($item in @(Get-List $attachmentQuality.samples.missing)) {
    $attachmentRows.Add(@{
        source_table = $item.source_table
        legacy_id = $item.legacy_id
        legacy_project_id = $item.legacy_project_id
        field = $item.field
        path = $item.path
        original_name = $item.original_name
        decision = ''
        replacement_path = ''
        exception_reason = ''
        approved_by = ''
    })
}

$unitHeaders = @('legacy_unit_id', 'unit_id', 'owner_id', 'project_count', 'status', 'resolution_note', 'approved_by')
$projectHeaders = @('legacy_project_id', 'new_project_id', 'project_title', 'project_db_status', 'attachment_count', 'ready_attachment_count', 'blocked_attachment_count', 'status', 'resolution_note', 'approved_by')
$attachmentHeaders = @('source_table', 'legacy_id', 'legacy_project_id', 'field', 'path', 'original_name', 'decision', 'replacement_path', 'exception_reason', 'approved_by')

Write-CsvRows 'unit_user_mapping_template' $UnitUserCsvPath $unitHeaders @($unitRows.ToArray())
Merge-CsvRows 'project_mapping_template' $ProjectCsvPath $projectHeaders @($projectRows.ToArray()) 'legacy_project_id'
Write-CsvRows 'attachment_exception_template' $AttachmentExceptionCsvPath $attachmentHeaders @($attachmentRows.ToArray())

$templates = @(
    New-TemplateArtifact 'unit_user_mapping_template' $UnitUserCsvPath @($unitRows.ToArray()) @('legacy_unit_id', 'unit_id', 'owner_id', 'approved_by') 'Fill production unit_id and owner_id values for legacy units.' $script:TemplateWriteResults['unit_user_mapping_template']
    New-TemplateArtifact 'project_mapping_template' $ProjectCsvPath @($projectRows.ToArray()) @('legacy_project_id', 'new_project_id', 'approved_by') 'Fill production new_project_id values for legacy projects.' $script:TemplateWriteResults['project_mapping_template']
    New-TemplateArtifact 'attachment_exception_template' $AttachmentExceptionCsvPath @($attachmentRows.ToArray()) @('legacy_project_id', 'decision', 'approved_by') 'Record recovered attachment paths or approved missing-file exceptions.' $script:TemplateWriteResults['attachment_exception_template']
)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = if ($Force) { 'template_generation_force' } else { 'template_generation_preserve_existing' }
    note = 'Existing CSV templates are preserved by default. Use -Force to recreate them from current reports.'
    summary = [ordered]@{
        template_count = $templates.Count
        unit_user_rows = @($unitRows).Count
        project_rows = @($projectRows).Count
        attachment_exception_rows = @($attachmentRows).Count
        action_sheet_items = if ($actionSheet) { Get-Number $actionSheet.summary.total_items } else { 0 }
        created_templates = @($script:TemplateWriteResults.Values | Where-Object { $_ -eq 'created' }).Count
        preserved_templates = @($script:TemplateWriteResults.Values | Where-Object { $_ -eq 'preserved' }).Count
        overwritten_templates = @($script:TemplateWriteResults.Values | Where-Object { $_ -eq 'overwritten' }).Count
    }
    templates = @($templates)
}

$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution templates written to $ReportPath"

