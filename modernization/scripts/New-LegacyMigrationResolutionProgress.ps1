param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-progress.json"),
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
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

function Test-PositiveInteger($value) {
    if (Test-Blank $value) { return $false }
    return [regex]::IsMatch([string]$value, '^[1-9][0-9]*$')
}

function Add-FieldCount($counts, $field) {
    if (-not $counts.ContainsKey($field)) { $counts[$field] = 0 }
    $counts[$field]++
}

function Convert-ToPercent($ready, $total) {
    if ($total -le 0) { return 100 }
    return [math]::Round(($ready * 100.0) / $total, 1)
}

function Convert-FieldCounts($counts) {
    $items = @()
    foreach ($key in $counts.Keys) {
        $items += [pscustomobject][ordered]@{
            field = $key
            count = $counts[$key]
        }
    }
    return @($items | Sort-Object -Property count -Descending | Select-Object -First 10)
}

function New-ProgressSummary($template, $target, $rows, $AnalyzeRow, $samples) {
    $ready = 0
    $pending = 0
    $blocked = 0
    $approved = 0
    $missingValueCount = 0
    $missingFieldCounts = @{}
    $rowNumber = 1

    foreach ($row in @($rows)) {
        $rowNumber++
        $result = & $AnalyzeRow $row

        if ($result.approved) { $approved++ }
        foreach ($field in @($result.missing_fields)) {
            $missingValueCount++
            Add-FieldCount $missingFieldCounts $field
        }

        if ($result.status -eq 'ready') { $ready++ }
        elseif ($result.status -eq 'pending') { $pending++ }
        else { $blocked++ }

        if (($result.status -ne 'ready') -and ($samples.Count -lt $SampleSize)) {
            $samples.Add([pscustomobject][ordered]@{
                template = $template
                target = $target
                row_number = $rowNumber
                legacy_id = $result.legacy_id
                status = $result.status
                missing_fields = @($result.missing_fields)
                invalid_fields = @($result.invalid_fields)
                action = $result.action
            })
        }
    }

    $total = @($rows).Count
    $action = if ($blocked -gt 0) {
        'Fix invalid or partially filled rows before import preview.'
    } elseif ($pending -gt 0) {
        'Fill required ids or decisions, then add approved_by.'
    } else {
        'Template rows are ready for resolved mapping preview.'
    }

    return [pscustomobject][ordered]@{
        template = $template
        target = $target
        total_rows = $total
        ready_rows = $ready
        pending_rows = $pending
        blocked_rows = $blocked
        approved_rows = $approved
        missing_required_values = $missingValueCount
        completion_percent = Convert-ToPercent $ready $total
        most_missing_fields = @(Convert-FieldCounts $missingFieldCounts)
        action = $action
    }
}

$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$samples = New-Object System.Collections.Generic.List[object]

$unitProgress = New-ProgressSummary 'legacy-unit-user-id-map.template.csv' 'unit_user_mapping' $unitRows {
    param($row)
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]

    if (-not (Test-PositiveInteger $row.legacy_unit_id)) { $invalid.Add('legacy_unit_id') }
    if (Test-Blank $row.unit_id) { $missing.Add('unit_id') } elseif (-not (Test-PositiveInteger $row.unit_id)) { $invalid.Add('unit_id') }
    if (Test-Blank $row.owner_id) { $missing.Add('owner_id') } elseif (-not (Test-PositiveInteger $row.owner_id)) { $invalid.Add('owner_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.unit_id) -and (Test-Blank $row.owner_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }

    [pscustomobject][ordered]@{
        legacy_id = $row.legacy_unit_id
        status = $status
        approved = -not (Test-Blank $row.approved_by)
        missing_fields = @($missing.ToArray())
        invalid_fields = @($invalid.ToArray())
        action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Fill unit_id, owner_id, and approved_by.' } else { 'Fix invalid or partially filled unit/user mapping row.' }
    }
} $samples

$projectProgress = New-ProgressSummary 'legacy-project-id-map.template.csv' 'project_mapping' $projectRows {
    param($row)
    $missing = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]

    if (-not (Test-PositiveInteger $row.legacy_project_id)) { $invalid.Add('legacy_project_id') }
    if (Test-Blank $row.new_project_id) { $missing.Add('new_project_id') } elseif (-not (Test-PositiveInteger $row.new_project_id)) { $invalid.Add('new_project_id') }
    if (Test-Blank $row.approved_by) { $missing.Add('approved_by') }

    $operatorBlank = (Test-Blank $row.new_project_id) -and (Test-Blank $row.approved_by)
    $status = if (($missing.Count -eq 0) -and ($invalid.Count -eq 0)) { 'ready' } elseif ($operatorBlank -and ($invalid.Count -eq 0)) { 'pending' } else { 'blocked' }

    [pscustomobject][ordered]@{
        legacy_id = $row.legacy_project_id
        status = $status
        approved = -not (Test-Blank $row.approved_by)
        missing_fields = @($missing.ToArray())
        invalid_fields = @($invalid.ToArray())
        action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Fill new_project_id and approved_by.' } else { 'Fix invalid or partially filled project mapping row.' }
    }
} $samples

$attachmentProgress = New-ProgressSummary 'legacy-attachment-exceptions.template.csv' 'attachment_exception' $attachmentRows {
    param($row)
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

    [pscustomobject][ordered]@{
        legacy_id = $row.legacy_id
        status = $status
        approved = -not (Test-Blank $row.approved_by)
        missing_fields = @($missing.ToArray())
        invalid_fields = @($invalid.ToArray())
        action = if ($status -eq 'ready') { 'ready' } elseif ($status -eq 'pending') { 'Choose recover or exception, fill the matching field, and add approved_by.' } else { 'Fix invalid or partially filled attachment exception row.' }
    }
} $samples

$byTemplate = @($unitProgress, $projectProgress, $attachmentProgress)
$totalRows = 0
$readyRows = 0
$pendingRows = 0
$blockedRows = 0
$approvedRows = 0
$missingValues = 0
foreach ($item in $byTemplate) {
    $totalRows += $item.total_rows
    $readyRows += $item.ready_rows
    $pendingRows += $item.pending_rows
    $blockedRows += $item.blocked_rows
    $approvedRows += $item.approved_rows
    $missingValues += $item.missing_required_values
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report measures operator CSV completion only. It does not import records, copy files, or write resolved maps.'
    overall_status = if ($blockedRows -gt 0) { 'blocked' } elseif ($readyRows -eq $totalRows) { 'ready' } else { 'not_ready' }
    summary = [ordered]@{
        total_rows = $totalRows
        ready_rows = $readyRows
        pending_rows = $pendingRows
        blocked_rows = $blockedRows
        approved_rows = $approvedRows
        missing_required_values = $missingValues
        completion_percent = Convert-ToPercent $readyRows $totalRows
    }
    by_template = @($byTemplate)
    sample_open_rows = @($samples.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration resolution progress written to $ReportPath"
