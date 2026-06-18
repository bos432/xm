param(
    [string]$UnitUserCsvPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.template.csv"),
    [string]$ProjectCsvPath = (Join-Path $PSScriptRoot "legacy-project-id-map.template.csv"),
    [string]$AttachmentExceptionCsvPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"),
    [string]$UnitUserReportPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.resolved.json"),
    [string]$ProjectReportPath = (Join-Path $PSScriptRoot "legacy-project-id-map.resolved.json"),
    [string]$AttachmentExceptionReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exceptions.resolved.json"),
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

function Add-Sample($list, $item, $limit) {
    if ($list.Count -lt $limit) { $list.Add($item) }
}

function Write-JsonReport($path, $report) {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
}

$unitRows = Read-CsvRows $UnitUserCsvPath
$projectRows = Read-CsvRows $ProjectCsvPath
$attachmentRows = Read-CsvRows $AttachmentExceptionCsvPath

$unitItems = New-Object System.Collections.Generic.List[object]
$unitReadySamples = New-Object System.Collections.Generic.List[object]
$unitPendingSamples = New-Object System.Collections.Generic.List[object]
$unitMapped = 0
$unitPending = 0
$unitBlocked = 0

foreach ($row in @($unitRows)) {
    $ready = (Test-PositiveInteger $row.legacy_unit_id) -and (Test-PositiveInteger $row.unit_id) -and (Test-PositiveInteger $row.owner_id) -and -not (Test-Blank $row.approved_by)
    $allBlank = (Test-Blank $row.unit_id) -and (Test-Blank $row.owner_id) -and (Test-Blank $row.approved_by)
    $warnings = @()
    $status = 'pending_unit_user_import'
    if ($ready) {
        $status = 'resolved_mapped'
        $unitMapped++
        $warnings = @('operator_resolved')
    } elseif ($allBlank) {
        $unitPending++
        $warnings = @('unit_id_missing', 'owner_id_missing', 'approved_by_missing')
    } else {
        $unitBlocked++
        $warnings = @('operator_row_incomplete_or_invalid')
    }

    $item = [pscustomobject][ordered]@{
        legacy_unit_id = if (Test-PositiveInteger $row.legacy_unit_id) { [int64]$row.legacy_unit_id } else { $row.legacy_unit_id }
        unit_id = if (Test-PositiveInteger $row.unit_id) { [int64]$row.unit_id } else { $null }
        owner_id = if (Test-PositiveInteger $row.owner_id) { [int64]$row.owner_id } else { $null }
        status = $status
        project_count = if (Test-PositiveInteger $row.project_count) { [int64]$row.project_count } else { 0 }
        resolution_note = $row.resolution_note
        approved_by = $row.approved_by
        warnings = @($warnings)
    }
    $unitItems.Add($item)
    if ($ready) { Add-Sample $unitReadySamples $item $SampleSize } else { Add-Sample $unitPendingSamples $item $SampleSize }
}

$projectItems = New-Object System.Collections.Generic.List[object]
$projectReadySamples = New-Object System.Collections.Generic.List[object]
$projectPendingSamples = New-Object System.Collections.Generic.List[object]
$projectMapped = 0
$projectPending = 0
$projectBlocked = 0

foreach ($row in @($projectRows)) {
    $ready = (Test-PositiveInteger $row.legacy_project_id) -and (Test-PositiveInteger $row.new_project_id) -and -not (Test-Blank $row.approved_by)
    $allBlank = (Test-Blank $row.new_project_id) -and (Test-Blank $row.approved_by)
    $warnings = @()
    $status = 'pending_project_import'
    if ($ready) {
        $status = 'resolved_mapped'
        $projectMapped++
        $warnings = @('operator_resolved')
    } elseif ($allBlank) {
        $projectPending++
        $warnings = @('new_project_id_missing', 'approved_by_missing')
    } else {
        $projectBlocked++
        $warnings = @('operator_row_incomplete_or_invalid')
    }

    $item = [pscustomobject][ordered]@{
        legacy_project_id = if (Test-PositiveInteger $row.legacy_project_id) { [int64]$row.legacy_project_id } else { $row.legacy_project_id }
        new_project_id = if (Test-PositiveInteger $row.new_project_id) { [int64]$row.new_project_id } else { $null }
        status = $status
        attachment_count = if (Test-PositiveInteger $row.attachment_count) { [int64]$row.attachment_count } else { 0 }
        ready_attachment_count = if (Test-PositiveInteger $row.ready_attachment_count) { [int64]$row.ready_attachment_count } else { 0 }
        blocked_attachment_count = if (Test-PositiveInteger $row.blocked_attachment_count) { [int64]$row.blocked_attachment_count } else { 0 }
        resolution_note = $row.resolution_note
        approved_by = $row.approved_by
        warnings = @($warnings)
    }
    $projectItems.Add($item)
    if ($ready) { Add-Sample $projectReadySamples $item $SampleSize } else { Add-Sample $projectPendingSamples $item $SampleSize }
}

$exceptionItems = New-Object System.Collections.Generic.List[object]
$exceptionReadySamples = New-Object System.Collections.Generic.List[object]
$exceptionPendingSamples = New-Object System.Collections.Generic.List[object]
$exceptionReady = 0
$exceptionPending = 0
$exceptionBlocked = 0

foreach ($row in @($attachmentRows)) {
    $decision = ([string]$row.decision).Trim().ToLowerInvariant()
    $validDecision = @('recover', 'exception') -contains $decision
    $decisionComplete = ($decision -eq 'recover' -and -not (Test-Blank $row.replacement_path)) -or ($decision -eq 'exception' -and -not (Test-Blank $row.exception_reason))
    $ready = (Test-PositiveInteger $row.legacy_project_id) -and $validDecision -and $decisionComplete -and -not (Test-Blank $row.approved_by)
    $allBlank = (Test-Blank $row.decision) -and (Test-Blank $row.replacement_path) -and (Test-Blank $row.exception_reason) -and (Test-Blank $row.approved_by)
    $status = 'pending_exception_decision'
    $warnings = @()
    if ($ready) {
        $status = 'resolved_exception'
        $exceptionReady++
        $warnings = @('operator_resolved')
    } elseif ($allBlank) {
        $exceptionPending++
        $warnings = @('decision_missing', 'approved_by_missing')
    } else {
        $exceptionBlocked++
        $warnings = @('operator_row_incomplete_or_invalid')
    }

    $item = [pscustomobject][ordered]@{
        source_table = $row.source_table
        legacy_id = $row.legacy_id
        legacy_project_id = if (Test-PositiveInteger $row.legacy_project_id) { [int64]$row.legacy_project_id } else { $row.legacy_project_id }
        field = $row.field
        path = $row.path
        original_name = $row.original_name
        decision = if ($validDecision) { $decision } else { $row.decision }
        replacement_path = $row.replacement_path
        exception_reason = $row.exception_reason
        approved_by = $row.approved_by
        status = $status
        warnings = @($warnings)
    }
    $exceptionItems.Add($item)
    if ($ready) { Add-Sample $exceptionReadySamples $item $SampleSize } else { Add-Sample $exceptionPendingSamples $item $SampleSize }
}

$unitReport = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_resolved_preview'
    source_csv = $UnitUserCsvPath
    summary = [ordered]@{ total_units = $unitItems.Count; mapped_units = $unitMapped; pending_units = $unitPending; blocked_units = $unitBlocked }
    samples = [ordered]@{ mapped = @($unitReadySamples.ToArray()); pending = @($unitPendingSamples.ToArray()) }
    items = @($unitItems.ToArray())
}

$projectReport = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_resolved_preview'
    source_csv = $ProjectCsvPath
    summary = [ordered]@{ total_projects = $projectItems.Count; mapped_projects = $projectMapped; pending_projects = $projectPending; blocked_projects = $projectBlocked }
    samples = [ordered]@{ mapped = @($projectReadySamples.ToArray()); pending = @($projectPendingSamples.ToArray()) }
    items = @($projectItems.ToArray())
}

$exceptionReport = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_resolved_preview'
    source_csv = $AttachmentExceptionCsvPath
    summary = [ordered]@{ total_exceptions = $exceptionItems.Count; ready_exceptions = $exceptionReady; pending_exceptions = $exceptionPending; blocked_exceptions = $exceptionBlocked }
    samples = [ordered]@{ ready = @($exceptionReadySamples.ToArray()); pending = @($exceptionPendingSamples.ToArray()) }
    items = @($exceptionItems.ToArray())
}

Write-JsonReport $UnitUserReportPath $unitReport
Write-JsonReport $ProjectReportPath $projectReport
Write-JsonReport $AttachmentExceptionReportPath $exceptionReport

Write-Host "Resolved unit/user map preview written to $UnitUserReportPath"
Write-Host "Resolved project map preview written to $ProjectReportPath"
Write-Host "Resolved attachment exceptions preview written to $AttachmentExceptionReportPath"
