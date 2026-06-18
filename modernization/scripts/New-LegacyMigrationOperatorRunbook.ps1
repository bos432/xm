param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-operator-runbook.md")
)

$ErrorActionPreference = 'Stop'

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Migration Operator Runbook'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines '## 1. Operating Principles'
Add-Line $lines
Add-Line $lines '- Run dry-run and report generation by default.'
Add-Line $lines '- Do not modify legacy business files.'
Add-Line $lines '- Do not write back to the legacy database.'
Add-Line $lines '- Real attachment copy must use the explicit Execute flag.'
Add-Line $lines '- Real database import requires backup, rollback, and acceptance sign-off.'
Add-Line $lines
Add-Line $lines '## 2. Report Pipeline'
Add-Line $lines
Add-Line $lines '```powershell'
Add-Line $lines 'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1 -WithMock'
Add-Line $lines '```'
Add-Line $lines
Add-Line $lines 'This command generates quality reports, mapping reports, dry-run reports, batch plans, artifact manifests, preflight checks, drill reports, and rollback templates.'
Add-Line $lines
Add-Line $lines '## 3. Validation Commands'
Add-Line $lines
Add-Line $lines '```powershell'
Add-Line $lines 'php -l modernization\backend\app\Http\Controllers\MigrationReadinessController.php'
Add-Line $lines 'php -l modernization\backend\app\Services\LegacyRecordImportService.php'
Add-Line $lines 'php -l modernization\backend\app\Console\Commands\ImportLegacyRecords.php'
Add-Line $lines 'npm run build'
Add-Line $lines '```'
Add-Line $lines
Add-Line $lines '## 4. Key Reports'
Add-Line $lines
Add-Line $lines '| Report | Purpose |'
Add-Line $lines '| --- | --- |'
Add-Line $lines '| legacy-migration-readiness-summary.json | Go/no-go summary |'
Add-Line $lines '| legacy-migration-preflight-checklist.json | Blockers and actions before go-live |'
Add-Line $lines '| legacy-migration-batch-plan.json | Batch order and dependencies |'
Add-Line $lines '| legacy-migration-artifact-manifest.json | Report archive completeness |'
Add-Line $lines '| legacy-migration-go-live-drill-report.md | Go-live drill template |'
Add-Line $lines '| legacy-migration-rollback-plan.md | Rollback plan template |'
Add-Line $lines
Add-Line $lines '## 5. Real Attachment Copy'
Add-Line $lines
Add-Line $lines 'Only after dry-run confirmation:'
Add-Line $lines
Add-Line $lines '```powershell'
Add-Line $lines 'PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyAttachmentImportDryRun.ps1 -Execute'
Add-Line $lines '```'
Add-Line $lines
Add-Line $lines 'After execution, inspect legacy-attachment-import-execute.json. Rollback may only touch files copied into the new private storage path by that report.'
Add-Line $lines
Add-Line $lines '## 6. Database Import Preconditions'
Add-Line $lines
Add-Line $lines '- legacy-unit-user-db-dry-run.json is ready.'
Add-Line $lines '- legacy-project-db-dry-run.json is ready.'
Add-Line $lines '- legacy-project-file-db-dry-run.json is ready.'
Add-Line $lines '- legacy-migration-batch-plan.json has no blocked stage.'
Add-Line $lines '- legacy-migration-preflight-checklist.json has no blocker.'
Add-Line $lines '- New DB snapshot, attachment target snapshot, and config backup are confirmed.'
Add-Line $lines
Add-Line $lines '## 6.1 Database Import Dry-Run Commands'
Add-Line $lines
Add-Line $lines '```powershell'
Add-Line $lines 'php artisan legacy:import-records units'
Add-Line $lines 'php artisan legacy:import-records users'
Add-Line $lines 'php artisan legacy:import-records projects'
Add-Line $lines 'php artisan legacy:import-records project_files'
Add-Line $lines 'php artisan legacy:import-records migration_batches'
Add-Line $lines 'php artisan legacy:import-records all'
Add-Line $lines 'php artisan legacy:import-records all --output=../scripts/legacy-record-import-plan.json'
Add-Line $lines '```'
Add-Line $lines
Add-Line $lines 'The legacy:import-records command currently supports dry-run preview only. The execute flag intentionally fails until real import is implemented. Use --output during rehearsal when the Laravel-side preview should be archived or exposed to the readiness dashboard.'
Add-Line $lines
Add-Line $lines '## 7. Go-Live Drill Flow'
Add-Line $lines
Add-Line $lines '1. Generate the full report pipeline.'
Add-Line $lines '2. Review the preflight checklist.'
Add-Line $lines '3. Sample-check projects, units, and attachments with business users.'
Add-Line $lines '4. Confirm backups, entry switching, and rollback with operations.'
Add-Line $lines '5. Fill in the go-live drill report.'
Add-Line $lines '6. Decide whether to enter the real execution window.'
Add-Line $lines
Add-Line $lines '## 8. Rollback Entry'
Add-Line $lines
Add-Line $lines '- Rollback plan: legacy-migration-rollback-plan.md.'
Add-Line $lines '- Rollback principle: prefer new DB snapshot restore; do not write to the legacy DB; do not delete legacy attachments.'
Add-Line $lines
Add-Line $lines '## 9. Manual Sign-Off'
Add-Line $lines
Add-Line $lines '| Role | Confirmation | Sign-off | Time |'
Add-Line $lines '| --- | --- | --- | --- |'
Add-Line $lines '| Technical owner | Migration reports have no blocker | TBD | TBD |'
Add-Line $lines '| Operations owner | Backup and rollback are executable | TBD | TBD |'
Add-Line $lines '| Business owner | Sampling acceptance passed | TBD | TBD |'
Add-Line $lines '| Security owner | Upload and download permissions passed | TBD | TBD |'

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration operator runbook written to $ReportPath"
