param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-operator-pack.json"),
    [string]$ConfirmationPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-confirmation.json"),
    [string]$WorksheetPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet.json"),
    [string]$ImportPreviewPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet-import-preview.json"),
    [string]$PatchPreviewPath = (Join-Path $PSScriptRoot "legacy-attachment-exception-template-patch-preview.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-Artifact($key, $path, $exists, $status, $purpose) {
    return [ordered]@{
        key = $key
        path = $path
        exists = [bool]$exists
        status = $status
        purpose = $purpose
    }
}

function Add-Step($steps, $order, $title, $status, $action, $acceptance, $source) {
    $steps.Add([pscustomobject][ordered]@{
        order = $order
        title = $title
        status = $status
        action = $action
        acceptance = $acceptance
        source = $source
    })
}

$confirmation = Read-JsonReport $ConfirmationPath
$worksheet = Read-JsonReport $WorksheetPath
$importPreview = Read-JsonReport $ImportPreviewPath
$patchPreview = Read-JsonReport $PatchPreviewPath

$steps = New-Object System.Collections.Generic.List[object]

$confirmationStatus = if ($confirmation) { $confirmation.overall_status } else { 'missing' }
Add-Step $steps 1 'Confirm missing attachment decisions' $confirmationStatus 'Choose recover or exception for each missing attachment and approve the decision.' 'No pending or blocked attachment exception decisions remain.' $ConfirmationPath

$worksheetStatus = if ($worksheet) { $worksheet.overall_status } else { 'missing' }
Add-Step $steps 2 'Fill business worksheet CSV' $worksheetStatus 'Fill decision, replacement_path or exception_reason, and approved_by in legacy-attachment-exception-worksheet.csv.' 'Worksheet rows are complete and ready for import preview.' $WorksheetPath

$importPreviewStatus = if ($importPreview) { $importPreview.overall_status } else { 'missing' }
Add-Step $steps 3 'Preview worksheet values against template' $importPreviewStatus 'Run the report pipeline and review ready, pending, and blocked worksheet import rows.' 'Ready rows can be manually copied into legacy-attachment-exceptions.template.csv.' $ImportPreviewPath

$patchStatus = if ($patchPreview) { $patchPreview.overall_status } else { 'missing' }
Add-Step $steps 4 'Review template patch preview' $patchStatus 'Review legacy-attachment-exception-template-patch-preview.csv before manually copying values into the template CSV.' 'Patch rows match approved worksheet decisions.' $PatchPreviewPath

$blockedSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'blocked' -or $_.status -eq 'missing' })
$pendingSteps = @($steps.ToArray() | Where-Object { $_.status -eq 'not_ready' -or $_.status -eq 'pending' })
$readySteps = @($steps.ToArray() | Where-Object { $_.status -eq 'ready' })

$nextStep = $null
foreach ($step in @($steps.ToArray())) {
    if ($step.status -ne 'ready') {
        $nextStep = $step
        break
    }
}

$worksheetCsvPath = if ($worksheet) { $worksheet.csv_path } else { Join-Path $PSScriptRoot "legacy-attachment-exception-worksheet.csv" }
$patchCsvPath = if ($patchPreview) { $patchPreview.patch_csv_path } else { Join-Path $PSScriptRoot "legacy-attachment-exception-template-patch-preview.csv" }

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'operator_pack'
    note = 'This operator pack summarizes the missing attachment exception workflow. It does not edit CSV files, copy files, or write database records.'
    overall_status = if ($blockedSteps.Count -gt 0) { 'blocked' } elseif ($pendingSteps.Count -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        missing_attachments = if ($confirmation) { $confirmation.summary.total_blocked_attachments } else { 0 }
        pending_decisions = if ($confirmation) { $confirmation.summary.pending_decisions } else { 0 }
        worksheet_rows = if ($worksheet) { $worksheet.summary.worksheet_rows } else { 0 }
        worksheet_pending_rows = if ($worksheet) { $worksheet.summary.pending_rows } else { 0 }
        import_ready_rows = if ($importPreview) { $importPreview.summary.ready_rows } else { 0 }
        import_pending_rows = if ($importPreview) { $importPreview.summary.pending_rows } else { 0 }
        patch_rows = if ($patchPreview) { $patchPreview.summary.ready_patch_rows } else { 0 }
        ready_steps = $readySteps.Count
        pending_steps = $pendingSteps.Count
        blocked_steps = $blockedSteps.Count
    }
    next_step = $nextStep
    operator_files = [ordered]@{
        worksheet_csv = $worksheetCsvPath
        patch_preview_csv = $patchCsvPath
        template_csv = Join-Path $PSScriptRoot "legacy-attachment-exceptions.template.csv"
    }
    artifacts = @(
        New-Artifact 'confirmation' $ConfirmationPath ($null -ne $confirmation) $confirmationStatus 'decision status for blocked attachment dry-run rows'
        New-Artifact 'worksheet' $WorksheetPath ($null -ne $worksheet) $worksheetStatus 'business-fillable missing attachment worksheet'
        New-Artifact 'worksheet_import_preview' $ImportPreviewPath ($null -ne $importPreview) $importPreviewStatus 'preview of copying worksheet values into exception template'
        New-Artifact 'template_patch_preview' $PatchPreviewPath ($null -ne $patchPreview) $patchStatus 'ready rows exported as template patch preview'
    )
    steps = @($steps.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy attachment exception operator pack written to $ReportPath"
