param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet-import-preview.json"),
    [string]$WorksheetCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet.csv"),
    [string]$TemplateCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function New-Key($row) {
    return "$($row.source_table)|$($row.legacy_id)|$($row.legacy_project_id)|$($row.field)"
}

function Get-TemplateValue($row, $field) {
    if (-not $row) { return '' }
    return [string]$row.$field
}

$worksheetRows = Read-CsvRows $WorksheetCsvPath
$templateRows = Read-CsvRows $TemplateCsvPath

$templateByKey = @{}
foreach ($row in @($templateRows)) {
    $templateByKey[(New-Key $row)] = $row
}

$items = New-Object System.Collections.Generic.List[object]
foreach ($row in @($worksheetRows)) {
    $key = New-Key $row
    $templateRow = if ($templateByKey.ContainsKey($key)) { $templateByKey[$key] } else { $null }
    $warnings = New-Object System.Collections.Generic.List[string]
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()

    if (-not $templateRow) { $warnings.Add('template_row_missing') }
    if (Test-Blank $decision) { $warnings.Add('decision_missing') }
    elseif (@('recover', 'exception') -notcontains $decision) { $warnings.Add('decision_invalid') }
    elseif ($decision -eq 'recover' -and (Test-Blank $row.replacement_path)) { $warnings.Add('replacement_path_missing') }
    elseif ($decision -eq 'exception' -and (Test-Blank $row.exception_reason)) { $warnings.Add('exception_reason_missing') }
    if (Test-Blank $row.approved_by) { $warnings.Add('approved_by_missing') }

    $operatorBlank = (Test-Blank $row.decision) -and (Test-Blank $row.replacement_path) -and (Test-Blank $row.exception_reason) -and (Test-Blank $row.approved_by)
    $status = if ($warnings.Count -eq 0) { 'ready' } elseif ($operatorBlank) { 'pending' } else { 'blocked' }

    $changes = @(
        [ordered]@{ field = 'decision'; current_value = Get-TemplateValue $templateRow 'decision'; preview_value = $decision }
        [ordered]@{ field = 'replacement_path'; current_value = Get-TemplateValue $templateRow 'replacement_path'; preview_value = [string]$row.replacement_path }
        [ordered]@{ field = 'exception_reason'; current_value = Get-TemplateValue $templateRow 'exception_reason'; preview_value = [string]$row.exception_reason }
        [ordered]@{ field = 'approved_by'; current_value = Get-TemplateValue $templateRow 'approved_by'; preview_value = [string]$row.approved_by }
    )

    $items.Add([pscustomobject][ordered]@{
        key = $key
        source_table = $row.source_table
        legacy_id = $row.legacy_id
        legacy_project_id = $row.legacy_project_id
        field = $row.field
        source_path = $row.source_path
        status = $status
        decision = $decision
        warnings = @($warnings.ToArray())
        preview_changes = @($changes)
        action = if ($status -eq 'ready') { 'Ready to manually copy values into legacy-attachment-exceptions.template.csv.' } elseif ($status -eq 'pending') { 'Fill decision and approved_by before import preview.' } else { 'Fix invalid or partially filled worksheet row before manual copy.' }
    })
}

$readyItems = @($items.ToArray() | Where-Object { $_.status -eq 'ready' })
$pendingItems = @($items.ToArray() | Where-Object { $_.status -eq 'pending' })
$blockedItems = @($items.ToArray() | Where-Object { $_.status -eq 'blocked' })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report previews copying worksheet decisions into legacy-attachment-exceptions.template.csv. It does not edit the template CSV.'
    worksheet_csv_path = $WorksheetCsvPath
    template_csv_path = $TemplateCsvPath
    overall_status = if ($blockedItems.Count -gt 0) { 'blocked' } elseif ($readyItems.Count -gt 0 -and $pendingItems.Count -eq 0) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        worksheet_rows = @($worksheetRows).Count
        template_rows = @($templateRows).Count
        ready_rows = $readyItems.Count
        pending_rows = $pendingItems.Count
        blocked_rows = $blockedItems.Count
    }
    samples = [ordered]@{
        ready = @($readyItems | Select-Object -First $SampleSize)
        pending = @($pendingItems | Select-Object -First $SampleSize)
        blocked = @($blockedItems | Select-Object -First $SampleSize)
    }
    items = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy attachment exception worksheet import preview written to $ReportPath"
