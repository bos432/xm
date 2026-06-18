param(
    [string]$ScriptsRoot = $PSScriptRoot,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-rollback-plan.md")
)

$ErrorActionPreference = 'Stop'

function Add-Line($lines, $text = '') {
    $lines.Add($text)
}

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Legacy Migration Rollback Plan'
Add-Line $lines
Add-Line $lines ('Generated at: ' + (Get-Date -Format o))
Add-Line $lines
Add-Line $lines '## 1. Rollback Goals'
Add-Line $lines
Add-Line $lines '- Keep the legacy system available for read-only historical lookup when needed.'
Add-Line $lines '- Stop new-system writes quickly if migration validation fails.'
Add-Line $lines '- Preserve evidence for database import, attachment copy, and configuration changes.'
Add-Line $lines '- Never write back to the legacy database during rollback.'
Add-Line $lines
Add-Line $lines '## 2. Rollback Triggers'
Add-Line $lines
Add-Line $lines '- Login, project submission, review, or attachment download is unavailable and cannot be fixed within the incident window.'
Add-Line $lines '- Data migration sampling shows systemic field, ownership, or status errors.'
Add-Line $lines '- Attachment migration shows missing files, wrong project ownership, or permission leakage.'
Add-Line $lines '- Error rate, slow requests, or security alerts exceed the accepted go-live threshold.'
Add-Line $lines
Add-Line $lines '## 3. Backup Confirmation'
Add-Line $lines
Add-Line $lines '| Item | Requirement | Owner | Time |'
Add-Line $lines '| --- | --- | --- | --- |'
Add-Line $lines '| Legacy DB read-only copy | Completed and connectable | TBD | TBD |'
Add-Line $lines '| New DB pre-go-live snapshot | Completed and restorable | TBD | TBD |'
Add-Line $lines '| Attachment target snapshot | File count and size recorded | TBD | TBD |'
Add-Line $lines '| New system configuration | .env, web server, queue config backed up | TBD | TBD |'
Add-Line $lines '| Legacy entry configuration | Read-only entry config backed up | TBD | TBD |'
Add-Line $lines
Add-Line $lines '## 4. Entry Rollback'
Add-Line $lines
Add-Line $lines '1. Pause new-system write entry points.'
Add-Line $lines '2. Enable the new-system maintenance notice.'
Add-Line $lines '3. Restore the legacy read-only historical lookup entry.'
Add-Line $lines '4. Keep the new admin entry available only for troubleshooting.'
Add-Line $lines '5. Record DNS, web server, reverse proxy, or load balancer change times.'
Add-Line $lines
Add-Line $lines '## 5. Database Rollback'
Add-Line $lines
Add-Line $lines '- If only dry-run was executed, no database rollback is required.'
Add-Line $lines '- If real import was executed, process migration batches in reverse order.'
Add-Line $lines '- Prefer restoring the new DB pre-go-live snapshot.'
Add-Line $lines '- If snapshot restore is impossible, delete newly imported records by batch metadata.'
Add-Line $lines '- Do not write any rollback data into the legacy database.'
Add-Line $lines
Add-Line $lines '## 6. Attachment Copy Rollback'
Add-Line $lines
Add-Line $lines '- If only dry-run was executed, no attachment rollback is required.'
Add-Line $lines '- If Execute copy was used, use legacy-attachment-import-execute.json as the only deletion source.'
Add-Line $lines '- Before deleting, verify every target path stays inside modernization/backend/storage/app/private.'
Add-Line $lines '- Never delete files from the legacy upload directory.'
Add-Line $lines
Add-Line $lines '## 7. Queue And Scheduler Rollback'
Add-Line $lines
Add-Line $lines '- Stop queue workers.'
Add-Line $lines '- Pause scheduled jobs.'
Add-Line $lines '- Keep failed jobs and logs for investigation.'
Add-Line $lines '- Replay jobs only after technical owner approval.'
Add-Line $lines
Add-Line $lines '## 8. Acceptance Checklist'
Add-Line $lines
Add-Line $lines '| Check | Result | Owner | Time |'
Add-Line $lines '| --- | --- | --- | --- |'
Add-Line $lines '| Legacy historical lookup works | TBD | TBD | TBD |'
Add-Line $lines '| New-system writes are paused | TBD | TBD | TBD |'
Add-Line $lines '| User notice is published | TBD | TBD | TBD |'
Add-Line $lines '| Data and attachments stopped changing | TBD | TBD | TBD |'
Add-Line $lines '| Error logs are archived | TBD | TBD | TBD |'
Add-Line $lines
Add-Line $lines '## 9. Postmortem Notes'
Add-Line $lines
Add-Line $lines '- Rollback reason: TBD'
Add-Line $lines '- Impact scope: TBD'
Add-Line $lines '- Fix plan: TBD'
Add-Line $lines '- Re-go-live criteria: TBD'

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration rollback plan written to $ReportPath"
