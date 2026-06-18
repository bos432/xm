# Migration Report Pipeline

This pipeline rebuilds the legacy migration reports in dependency order. It only generates reports by default and does not copy files or write database records.

## Default report rebuild

```powershell
PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1
```

Default mode produces or refreshes:

- `legacy-attachment-quality.json`
- `legacy-attachment-import-index.json`
- `legacy-attachment-import-dry-run.json`
- `legacy-attachment-exception-confirmation.json`
- `legacy-attachment-exception-worksheet.json`
- `legacy-attachment-exception-worksheet.csv`
- `legacy-attachment-exception-worksheet-import-preview.json`
- `legacy-attachment-exception-template-patch-preview.json`
- `legacy-attachment-exception-template-patch-preview.csv`
- `legacy-attachment-exception-operator-pack.json`
- `legacy-attachment-exception-operator-pack-validation.json`
- `legacy-migration-blocker-action-sheet.json`
- `legacy-migration-blocker-action-sheet-validation.json`
- `legacy-migration-blocker-resolution-pack-validation.json`
- `legacy-migration-resolution-operator-pack.json`
- `legacy-migration-resolution-operator-pack-validation.json`
- `legacy-migration-sampling-acceptance-operator-pack-validation.json`
- `legacy-workflow-orphan-operator-pack-validation.json`
- `legacy-migration-artifact-manifest-validation.json`
- `legacy-migration-go-live-gate-validation.json`
- `legacy-migration-preflight-checklist-validation.json`
- `legacy-migration-go-live-evidence-pack-validation.json`
- `legacy-migration-next-actions-validation.json`
- `legacy-migration-next-actions.blockers.csv`
- `legacy-migration-next-actions.blockers.md`
- `legacy-migration-next-actions.owner-files.json`
- `legacy-migration-next-actions.owner-files.zip`
- `legacy-migration-next-actions.owner-files-validation.json`
- `legacy-migration-next-actions.owner-signoff.json`
- `legacy-migration-next-actions.owner-signoff.csv`
- `legacy-migration-next-actions.owner-signoff-validation.json`
- `legacy-migration-next-actions.owner-signoff-operator-pack.json`
- `legacy-migration-next-actions.owner-signoff-operator-pack-validation.json`
- `legacy-migration-next-actions.owner.<owner>.csv`
- `legacy-migration-next-actions.owner.<owner>.md`
- `legacy-migration-next-actions.owner.<owner>.blockers.csv`
- `legacy-migration-next-actions.owner.<owner>.blockers.md`
- `legacy-migration-operational-docs-validation.json`
- `legacy-project-db-dry-run.json`
- `legacy-unit-user-id-map.json`
- `legacy-project-file-db-dry-run.json`
- `legacy-migration-resolution-templates.json`
- `legacy-migration-resolution-validation.json`
- `legacy-migration-resolution-progress.json`
- `legacy-migration-resolution-worklist.json`
- `legacy-migration-resolution-worklist.csv`
- `legacy-migration-resolution-import-preview.json`
- `legacy-unit-user-id-map.resolved.json`
- `legacy-project-id-map.resolved.json`
- `legacy-attachment-exceptions.resolved.json`
- `legacy-migration-dry-run-comparison.json`

## Go-live readiness refresh

Use this after changing preflight, go-live gate, evidence, drill, or next-action report logic when the full migration pipeline does not need to be rebuilt.

```powershell
PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyGoLiveReadinessRefresh.ps1
```

This refresh only rebuilds downstream go-live readiness reports. It does not copy attachments, import records, switch traffic, update templates, or write database records. It also refreshes the security baseline operator pack validation, attachment exception operator pack validation, blocker action sheet validation, next actions validation, owner-specific next-action file validation, owner signoff, owner signoff validation, owner signoff operator pack, owner signoff operator pack validation, operational docs validation, resolution operator pack validation, go-live signoff operator pack validation, sampling acceptance operator pack validation, workflow orphan operator pack validation, artifact manifest validation, preflight checklist validation, go-live gate validation, go-live evidence pack validation, go-live drill operator pack validation, preflight blocker operator pack validation, blocker resolution operator pack validation, public executable security worklist, validation report, wave-based remediation plan, remediation plan validation, wave-specific remediation file package, wave package validation, wave signoff, wave signoff operator pack, operator pack validation, handoff pack, handoff pack validation, handoff signoff, handoff signoff validation, handoff signoff operator pack, and handoff signoff operator pack validation used by the security baseline operator pack.

The go-live readiness reports intentionally reference each other: the preflight checklist summarizes security and drill packs, while the drill pack also summarizes preflight. The refresh script therefore runs a seed pass followed by a final convergence pass so one command leaves the gate, evidence pack, drill pack, next actions, and artifact manifest aligned with the latest generated reports.


## Resolution template protection

The pipeline preserves existing operator CSV templates by default:

- `legacy-unit-user-id-map.template.csv`
- `legacy-project-id-map.template.csv`
- `legacy-attachment-exceptions.template.csv`

Use this only when you intentionally want to recreate blank templates from the latest reports:

```powershell
PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1 -ForceResolutionTemplates
```

## Mock mapping validation

```powershell
PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1 -WithMock
```

Mock mode additionally produces:

- `legacy-project-id-map.mock.json`
- `legacy-unit-user-id-map.mock.json`
- `legacy-unit-user-db-dry-run.mock.json`
- `legacy-project-db-dry-run.mock.json`
- `legacy-project-file-db-dry-run.mock.json`

Mock IDs are only for validating downstream readiness. They must not be used as production IDs.

## Safety boundary

- The pipeline does not execute attachment copying.
- The pipeline does not write to MySQL.
- Actual attachment copying still requires explicitly running `Invoke-LegacyAttachmentImportDryRun.ps1 -Execute` after reviewing dry-run reports.

