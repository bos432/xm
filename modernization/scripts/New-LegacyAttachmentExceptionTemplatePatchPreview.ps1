param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-template-patch-preview.json"),
    [string]$PatchCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-template-patch-preview.csv"),
    [string]$ImportPreviewPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet-import-preview.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PreviewValue($changes, $field) {
    foreach ($change in @($changes)) {
        if ($change.field -eq $field) { return [string]$change.preview_value }
    }
    return ''
}

$importPreview = Read-JsonReport $ImportPreviewPath
$patchRows = New-Object System.Collections.Generic.List[object]

if ($importPreview -and $importPreview.items) {
    foreach ($item in @($importPreview.items)) {
        if ($item.status -ne 'ready') { continue }
        $patchRows.Add([pscustomobject][ordered]@{
            source_table = $item.source_table
            legacy_id = $item.legacy_id
            legacy_project_id = $item.legacy_project_id
            field = $item.field
            path = $item.source_path
            original_name = ''
            decision = Get-PreviewValue $item.preview_changes 'decision'
            replacement_path = Get-PreviewValue $item.preview_changes 'replacement_path'
            exception_reason = Get-PreviewValue $item.preview_changes 'exception_reason'
            approved_by = Get-PreviewValue $item.preview_changes 'approved_by'
        })
    }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This patch preview exports rows that are ready to be manually copied into legacy-attachment-exceptions.template.csv. It does not edit the template CSV.'
    source_report = $ImportPreviewPath
    patch_csv_path = $PatchCsvPath
    overall_status = if (-not $importPreview) { 'missing' } elseif ($patchRows.Count -gt 0) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        ready_patch_rows = $patchRows.Count
        source_ready_rows = if ($importPreview) { $importPreview.summary.ready_rows } else { 0 }
        source_pending_rows = if ($importPreview) { $importPreview.summary.pending_rows } else { 0 }
        source_blocked_rows = if ($importPreview) { $importPreview.summary.blocked_rows } else { 0 }
    }
    columns = @('source_table', 'legacy_id', 'legacy_project_id', 'field', 'path', 'original_name', 'decision', 'replacement_path', 'exception_reason', 'approved_by')
    rows = @($patchRows.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
@($patchRows.ToArray()) | Export-Csv -LiteralPath $PatchCsvPath -Encoding UTF8 -NoTypeInformation

Write-Host "Legacy attachment exception template patch preview written to $ReportPath"
Write-Host "Legacy attachment exception template patch preview CSV written to $PatchCsvPath"
