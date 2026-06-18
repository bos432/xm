param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet.csv"),
    [string]$ConfirmationPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-confirmation.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Join-Values($values) {
    $items = @($values | Where-Object { $_ })
    if ($items.Count -eq 0) { return '' }
    return ($items -join ';')
}

$confirmation = Read-JsonReport $ConfirmationPath
$items = New-Object System.Collections.Generic.List[object]

if ($confirmation -and $confirmation.items) {
    foreach ($item in @($confirmation.items)) {
        $missing = @($item.warnings)
        $currentDecision = ([string]$item.decision).Trim().ToLowerInvariant()
        $suggestedDecision = if ($currentDecision) { $currentDecision } else { 'exception' }
        $suggestedReason = if ($currentDecision -eq 'recover') { '' } elseif ($item.exception_reason) { $item.exception_reason } else { 'Legacy source file missing during dry-run; business confirmation required.' }

        $items.Add([pscustomobject][ordered]@{
            source_table = $item.source_table
            legacy_id = $item.legacy_id
            legacy_project_id = $item.legacy_project_id
            field = $item.field
            source_path = $item.source_path
            target_path = $item.target_path
            current_status = $item.status
            missing_fields = Join-Values $missing
            suggested_decision = $suggestedDecision
            suggested_exception_reason = $suggestedReason
            decision = $item.decision
            replacement_path = $item.replacement_path
            exception_reason = $item.exception_reason
            approved_by = $item.approved_by
            operator_note = ''
            acceptance = 'Fill decision as recover or exception. For recover, fill replacement_path. For exception, fill exception_reason. Always fill approved_by.'
        })
    }
}

$readyRows = @($items.ToArray() | Where-Object { $_.current_status -eq 'ready' })
$pendingRows = @($items.ToArray() | Where-Object { $_.current_status -eq 'pending' })
$blockedRows = @($items.ToArray() | Where-Object { $_.current_status -eq 'blocked' })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'worksheet_only'
    note = 'This worksheet is for business confirmation. It does not update legacy-attachment-exceptions.template.csv, copy files, or write database records.'
    source_report = $ConfirmationPath
    csv_path = $CsvPath
    overall_status = if (-not $confirmation) { 'missing' } elseif ($blockedRows.Count -gt 0) { 'blocked' } elseif ($pendingRows.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        worksheet_rows = $items.Count
        ready_rows = $readyRows.Count
        pending_rows = $pendingRows.Count
        blocked_rows = $blockedRows.Count
    }
    columns = @('source_table', 'legacy_id', 'legacy_project_id', 'field', 'source_path', 'target_path', 'current_status', 'missing_fields', 'suggested_decision', 'suggested_exception_reason', 'decision', 'replacement_path', 'exception_reason', 'approved_by', 'operator_note', 'acceptance')
    rows = @($items.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
@($items.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation

Write-Host "Legacy attachment exception worksheet written to $ReportPath"
Write-Host "Legacy attachment exception worksheet CSV written to $CsvPath"
