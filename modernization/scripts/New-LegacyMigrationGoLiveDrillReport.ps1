param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-drill-report.md")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

function Get-Value($value, $fallback = '0') {
    if ($null -eq $value) { return $fallback }
    return [string]$value
}

function Get-ReportStatus($report) {
    if ($null -eq $report) { return 'report_missing' }
    return Get-Value $report.overall_status 'unknown'
}

function Get-ReportValue($report, $value, $fallback = 'report_missing') {
    if ($null -eq $report) { return $fallback }
    return Get-Value $value $fallback
}

$readiness = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-readiness-summary.json')
$preflight = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-preflight-checklist.json')
$batchPlan = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-batch-plan.json')
$manifest = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-migration-artifact-manifest.json')
$attachmentDryRun = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-attachment-import-dry-run.json')
$projectDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.json')
$unitUserDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.json')
$projectFileDb = Read-JsonReport (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.json')

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Migration Go-Live Drill Report'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines '## 1. Overall Status'
Add-Line $lines
Add-Line $lines ('- Readiness status: ' + (Get-ReportStatus $readiness))
Add-Line $lines ('- Preflight status: ' + (Get-ReportStatus $preflight))
Add-Line $lines ('- Batch plan status: ' + (Get-ReportStatus $batchPlan))
Add-Line $lines
Add-Line $lines '## 2. Core Data Scope'
Add-Line $lines
Add-Line $lines ('- Units: ' + (Get-ReportValue $unitUserDb $unitUserDb.summary.total_units))
Add-Line $lines ('- Users: ' + (Get-ReportValue $unitUserDb $unitUserDb.summary.total_users))
Add-Line $lines ('- Projects: ' + (Get-ReportValue $projectDb $projectDb.summary.total_records))
Add-Line $lines ('- Project files: ' + (Get-ReportValue $projectFileDb $projectFileDb.summary.total_records))
Add-Line $lines ('- Attachment copy items: ' + (Get-ReportValue $attachmentDryRun $attachmentDryRun.summary.total_items))
Add-Line $lines
Add-Line $lines '## 3. Attachment Dry-Run'
Add-Line $lines
if ($attachmentDryRun) {
    Add-Line $lines ('- Ready items: ' + (Get-Value $attachmentDryRun.summary.ready_items))
    Add-Line $lines ('- Blocked items: ' + (Get-Value $attachmentDryRun.summary.blocked_items))
    Add-Line $lines ('- Duplicate target paths: ' + (Get-Value $attachmentDryRun.summary.duplicate_target_paths))
    Add-Line $lines ('- Target path escapes root: ' + (Get-Value $attachmentDryRun.summary.target_path_escapes_root))
    Add-Line $lines ('- Would copy bytes: ' + (Get-Value $attachmentDryRun.summary.would_copy_bytes))
} else {
    Add-Line $lines '- Attachment dry-run report is missing.'
}
Add-Line $lines
Add-Line $lines '## 4. Batch Import Plan'
Add-Line $lines
if ($batchPlan) {
    Add-Line $lines '| Order | Stage | Status | Planned | Ready | Waiting | Blocked |'
    Add-Line $lines '| --- | --- | --- | ---: | ---: | ---: | ---: |'
    foreach ($stage in @($batchPlan.stages)) {
        Add-Line $lines (('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f $stage.order, $stage.key, $stage.status, $stage.planned_count, $stage.ready_count, $stage.waiting_count, $stage.blocked_count))
    }
} else {
    Add-Line $lines '- Batch plan report is missing.'
}
Add-Line $lines
Add-Line $lines '## 5. Preflight Items'
Add-Line $lines
if ($preflight) {
    Add-Line $lines '| Severity | Category | Title | Status | Action |'
    Add-Line $lines '| --- | --- | --- | --- | --- |'
    foreach ($item in @($preflight.items)) {
        Add-Line $lines (('| {0} | {1} | {2} | {3} | {4} |' -f $item.severity, $item.category, $item.title, $item.status, $item.action))
    }
} else {
    Add-Line $lines '- Preflight checklist is missing.'
}
Add-Line $lines
Add-Line $lines '## 6. Artifact Manifest'
Add-Line $lines
if ($manifest) {
    Add-Line $lines ('- Total artifacts: ' + (Get-Value $manifest.summary.total_artifacts))
    Add-Line $lines ('- Existing artifacts: ' + (Get-Value $manifest.summary.existing_artifacts))
    Add-Line $lines ('- Missing required: ' + (Get-Value $manifest.summary.missing_required))
    Add-Line $lines ('- Missing optional: ' + (Get-Value $manifest.summary.missing_optional))
} else {
    Add-Line $lines '- Artifact manifest is missing.'
}
Add-Line $lines
Add-Line $lines '## 7. Drill Sign-Off'
Add-Line $lines
Add-Line $lines '- Ops owner: TBD'
Add-Line $lines '- Business owner: TBD'
Add-Line $lines '- Rollback drill: TBD'
Add-Line $lines '- Go-live window: TBD'
Add-Line $lines '- Residual risks: TBD'

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration go-live drill report written to $ReportPath"
