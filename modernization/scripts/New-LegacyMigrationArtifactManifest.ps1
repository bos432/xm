param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-artifact-manifest.json")
)

$ErrorActionPreference = 'Stop'

function New-Artifact($key, $type, $path, $purpose, $required, $dependsOn = @()) {
    $absolutePath = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $Root $path }
    $exists = Test-Path -LiteralPath $absolutePath
    return [ordered]@{
        key = $key
        type = $type
        path = $absolutePath
        purpose = $purpose
        required = [bool]$required
        exists = $exists
        updated_at = if ($exists) { (Get-Item -LiteralPath $absolutePath).LastWriteTime.ToString('o') } else { $null }
        size_bytes = if ($exists -and (Test-Path -LiteralPath $absolutePath -PathType Leaf)) { (Get-Item -LiteralPath $absolutePath).Length } else { $null }
        depends_on = @($dependsOn)
    }
}

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-ArtifactKeyToken($value) {
    $token = ([string]$value).Trim().ToLowerInvariant()
    $token = [regex]::Replace($token, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($token)) { return 'unassigned' }
    return $token
}

$artifacts = @(
    New-Artifact 'legacy_core_tables' 'text_report' 'scripts/legacy-core-tables.txt' 'legacy core table list' $true
    New-Artifact 'legacy_risk_report' 'text_report' 'scripts/legacy-risk-report.txt' 'legacy public directory risk scan' $true
    New-Artifact 'legacy_security_baseline_operator_pack' 'json_report' 'scripts/legacy-security-baseline-operator-pack.json' 'operator pack for legacy security baseline review' $true @('legacy_risk_report', 'legacy_attachment_quality')
    New-Artifact 'legacy_security_baseline_operator_pack_validation' 'json_report' 'scripts/legacy-security-baseline-operator-pack-validation.json' 'validation report for legacy security baseline operator pack' $true @('legacy_security_baseline_operator_pack')
    New-Artifact 'legacy_security_baseline_signoff' 'json_report' 'scripts/legacy-security-baseline-signoff.json' 'manual security baseline mitigation and risk acceptance signoff' $true @('legacy_security_baseline_operator_pack')
    New-Artifact 'legacy_security_baseline_signoff_csv' 'csv_report' 'scripts/legacy-security-baseline-signoff.csv' 'manual security baseline signoff CSV' $true @('legacy_security_baseline_signoff')
    New-Artifact 'legacy_security_baseline_signoff_validation' 'json_report' 'scripts/legacy-security-baseline-signoff-validation.json' 'security baseline signoff field validation' $true @('legacy_security_baseline_signoff')
    New-Artifact 'legacy_security_public_executable_worklist' 'json_report' 'scripts/legacy-security-public-executable-worklist.json' 'operator worklist for public executable files' $true @('legacy_risk_report')
    New-Artifact 'legacy_security_public_executable_worklist_csv' 'csv_report' 'scripts/legacy-security-public-executable-worklist.csv' 'CSV operator worklist for public executable files' $true @('legacy_security_public_executable_worklist')
    New-Artifact 'legacy_security_public_executable_worklist_md' 'markdown_report' 'scripts/legacy-security-public-executable-worklist.md' 'Markdown operator worklist for public executable files' $true @('legacy_security_public_executable_worklist')
    New-Artifact 'legacy_security_public_executable_worklist_validation' 'json_report' 'scripts/legacy-security-public-executable-worklist-validation.json' 'validation report for public executable worklist fields' $true @('legacy_security_public_executable_worklist_csv')
    New-Artifact 'legacy_security_public_executable_remediation_plan' 'json_report' 'scripts/legacy-security-public-executable-remediation-plan.json' 'wave-based remediation plan for public executable files' $true @('legacy_security_public_executable_worklist')
    New-Artifact 'legacy_security_public_executable_remediation_plan_csv' 'csv_report' 'scripts/legacy-security-public-executable-remediation-plan.csv' 'CSV wave-based remediation plan for public executable files' $true @('legacy_security_public_executable_remediation_plan')
    New-Artifact 'legacy_security_public_executable_remediation_plan_md' 'markdown_report' 'scripts/legacy-security-public-executable-remediation-plan.md' 'Markdown wave-based remediation plan for public executable files' $true @('legacy_security_public_executable_remediation_plan')
    New-Artifact 'legacy_security_public_executable_remediation_plan_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-plan-validation.json' 'validation report for public executable remediation plan coverage and wave counts' $true @('legacy_security_public_executable_remediation_plan')
    New-Artifact 'legacy_security_public_executable_remediation_wave_files' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-files.json' 'manifest for wave-specific public executable remediation files' $true @('legacy_security_public_executable_remediation_plan_validation')
    New-Artifact 'legacy_security_public_executable_remediation_wave_files_zip' 'archive' 'scripts/legacy-security-public-executable-remediation-wave-files.zip' 'ZIP package for wave-specific public executable remediation files' $true @('legacy_security_public_executable_remediation_wave_files')
    New-Artifact 'legacy_security_public_executable_remediation_wave_files_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-files-validation.json' 'validation report for wave-specific public executable remediation files and ZIP contents' $true @('legacy_security_public_executable_remediation_wave_files_zip')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff.json' 'manual signoff sheet for public executable remediation waves' $true @('legacy_security_public_executable_remediation_wave_files')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_csv' 'csv_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff.csv' 'manual signoff CSV for public executable remediation waves' $true @('legacy_security_public_executable_remediation_wave_signoff')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-validation.json' 'validation report for public executable remediation wave signoff fields' $true @('legacy_security_public_executable_remediation_wave_signoff')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_operator_pack' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-operator-pack.json' 'operator pack for public executable remediation wave signoff' $true @('legacy_security_public_executable_remediation_wave_signoff', 'legacy_security_public_executable_remediation_wave_signoff_validation', 'legacy_security_public_executable_remediation_wave_files_validation')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json' 'validation report for public executable remediation wave signoff operator pack' $true @('legacy_security_public_executable_remediation_wave_signoff_operator_pack')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_pack' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json' 'handoff pack for public executable remediation wave signoff' $true @('legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_csv' 'csv_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack.csv' 'CSV manifest for public executable remediation wave signoff handoff pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_pack')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_md' 'markdown_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack.md' 'Markdown manifest for public executable remediation wave signoff handoff pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_pack')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_zip' 'archive' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack.zip' 'ZIP package for public executable remediation wave signoff handoff' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_pack')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json' 'validation report for public executable remediation wave signoff handoff pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_pack_zip')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json' 'manual receipt signoff for public executable remediation wave signoff handoff pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_pack')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_csv' 'csv_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.csv' 'manual receipt signoff CSV for public executable remediation wave signoff handoff pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_signoff')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json' 'validation report for public executable remediation wave signoff handoff signoff fields' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_signoff')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json' 'operator pack for public executable remediation wave signoff handoff receipt' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_signoff', 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation')
    New-Artifact 'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' 'json_report' 'scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json' 'validation report for public executable remediation wave signoff handoff receipt operator pack' $true @('legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack')
    New-Artifact 'legacy_import_dry_run' 'json_report' 'scripts/legacy-import-dry-run.json' 'legacy core table dry-run stats' $true @('legacy_core_tables')
    New-Artifact 'legacy_migration_preview' 'json_report' 'scripts/legacy-migration-preview.json' 'legacy field to new model preview' $true @('legacy_import_dry_run')

    New-Artifact 'legacy_attachment_quality' 'json_report' 'scripts/legacy-attachment-quality.json' 'attachment existence and risk quality report' $true @('legacy_migration_preview')
    New-Artifact 'legacy_attachment_import_index' 'json_report' 'scripts/legacy-attachment-import-index.json' 'attachment import index json' $true @('legacy_attachment_quality')
    New-Artifact 'legacy_attachment_import_index_csv' 'csv_report' 'scripts/legacy-attachment-import-index.csv' 'attachment import index csv' $false @('legacy_attachment_import_index')
    New-Artifact 'legacy_attachment_import_dry_run' 'json_report' 'scripts/legacy-attachment-import-dry-run.json' 'attachment copy dry-run' $true @('legacy_attachment_import_index')
    New-Artifact 'legacy_attachment_exception_confirmation' 'json_report' 'scripts/legacy-attachment-exception-confirmation.json' 'blocked attachment exception confirmation report' $true @('legacy_attachment_import_dry_run')
    New-Artifact 'legacy_attachment_exception_worksheet' 'json_report' 'scripts/legacy-attachment-exception-worksheet.json' 'business worksheet for blocked attachment exception decisions' $true @('legacy_attachment_exception_confirmation')
    New-Artifact 'legacy_attachment_exception_worksheet_csv' 'csv_report' 'scripts/legacy-attachment-exception-worksheet.csv' 'business worksheet CSV for blocked attachment exception decisions' $true @('legacy_attachment_exception_worksheet')
    New-Artifact 'legacy_attachment_exception_worksheet_import_preview' 'json_report' 'scripts/legacy-attachment-exception-worksheet-import-preview.json' 'preview for applying worksheet values to attachment exception template' $true @('legacy_attachment_exception_worksheet_csv')
    New-Artifact 'legacy_attachment_exception_template_patch_preview' 'json_report' 'scripts/legacy-attachment-exception-template-patch-preview.json' 'patch preview for attachment exception template rows' $true @('legacy_attachment_exception_worksheet_import_preview')
    New-Artifact 'legacy_attachment_exception_template_patch_preview_csv' 'csv_report' 'scripts/legacy-attachment-exception-template-patch-preview.csv' 'patch preview CSV for attachment exception template rows' $true @('legacy_attachment_exception_template_patch_preview')
    New-Artifact 'legacy_attachment_exception_operator_pack' 'json_report' 'scripts/legacy-attachment-exception-operator-pack.json' 'operator pack for missing attachment exception workflow' $true @('legacy_attachment_exception_template_patch_preview')
    New-Artifact 'legacy_attachment_exception_operator_pack_validation' 'json_report' 'scripts/legacy-attachment-exception-operator-pack-validation.json' 'validation report for missing attachment exception operator pack' $true @('legacy_attachment_exception_operator_pack')
    New-Artifact 'legacy_attachment_import_execute' 'json_report' 'scripts/legacy-attachment-import-execute.json' 'attachment copy execute report, produced only with explicit Execute' $false @('legacy_attachment_import_dry_run')

    New-Artifact 'legacy_unit_user_db_dry_run' 'json_report' 'scripts/legacy-unit-user-db-dry-run.json' 'units and users table preview' $true @('legacy_migration_preview')
    New-Artifact 'legacy_unit_user_id_map' 'json_report' 'scripts/legacy-unit-user-id-map.json' 'legacy unit to new unit and owner id map placeholder' $true @('legacy_project_db_dry_run')
    New-Artifact 'legacy_unit_user_id_map_mock' 'json_report' 'scripts/legacy-unit-user-id-map.mock.json' 'mock unit and user id map for chain validation' $false @('legacy_unit_user_id_map')
    New-Artifact 'legacy_unit_user_db_dry_run_mock' 'json_report' 'scripts/legacy-unit-user-db-dry-run.mock.json' 'mock mapped units and users import preview' $false @('legacy_unit_user_db_dry_run', 'legacy_unit_user_id_map_mock')

    New-Artifact 'legacy_project_db_dry_run' 'json_report' 'scripts/legacy-project-db-dry-run.json' 'projects table preview' $true @('legacy_unit_user_db_dry_run')
    New-Artifact 'legacy_project_id_map' 'json_report' 'scripts/legacy-project-id-map.json' 'legacy project to new project id map placeholder' $true @('legacy_project_db_dry_run')
    New-Artifact 'legacy_project_id_map_mock' 'json_report' 'scripts/legacy-project-id-map.mock.json' 'mock project id map for chain validation' $false @('legacy_project_id_map')
    New-Artifact 'legacy_project_db_dry_run_mock' 'json_report' 'scripts/legacy-project-db-dry-run.mock.json' 'mock mapped projects import preview' $false @('legacy_project_db_dry_run', 'legacy_unit_user_id_map_mock')

    New-Artifact 'legacy_project_file_db_dry_run' 'json_report' 'scripts/legacy-project-file-db-dry-run.json' 'project files table preview' $true @('legacy_attachment_import_dry_run', 'legacy_project_id_map')
    New-Artifact 'legacy_project_file_db_dry_run_mock' 'json_report' 'scripts/legacy-project-file-db-dry-run.mock.json' 'mock mapped project files import preview' $false @('legacy_project_file_db_dry_run', 'legacy_project_id_map_mock')
    New-Artifact 'legacy_workflow_db_dry_run' 'json_report' 'scripts/legacy-workflow-db-dry-run.json' 'workflow reviews and operation logs row-level preview' $true @('legacy_import_dry_run', 'legacy_project_id_map')
    New-Artifact 'legacy_workflow_db_dry_run_mock' 'json_report' 'scripts/legacy-workflow-db-dry-run.mock.json' 'mock mapped workflow reviews and operation logs preview' $false @('legacy_workflow_db_dry_run', 'legacy_project_id_map_mock')
    New-Artifact 'legacy_workflow_orphan_resolution_signoff' 'json_report' 'scripts/legacy-workflow-orphan-resolution-signoff.json' 'manual handling decisions for workflow rows referencing missing legacy projects' $true @('legacy_workflow_db_dry_run')
    New-Artifact 'legacy_workflow_orphan_resolution_signoff_csv' 'csv_report' 'scripts/legacy-workflow-orphan-resolution-signoff.csv' 'manual workflow orphan handling CSV' $true @('legacy_workflow_orphan_resolution_signoff')
    New-Artifact 'legacy_workflow_orphan_resolution_signoff_validation' 'json_report' 'scripts/legacy-workflow-orphan-resolution-signoff-validation.json' 'validation report for workflow orphan handling decisions' $true @('legacy_workflow_orphan_resolution_signoff')
    New-Artifact 'legacy_workflow_orphan_operator_pack' 'json_report' 'scripts/legacy-workflow-orphan-operator-pack.json' 'operator pack for orphan workflow handling decisions' $true @('legacy_workflow_orphan_resolution_signoff', 'legacy_workflow_orphan_resolution_signoff_validation')
    New-Artifact 'legacy_workflow_orphan_operator_pack_validation' 'json_report' 'scripts/legacy-workflow-orphan-operator-pack-validation.json' 'validation report for orphan workflow operator pack' $true @('legacy_workflow_orphan_operator_pack')

    New-Artifact 'legacy_migration_readiness_summary' 'json_report' 'scripts/legacy-migration-readiness-summary.json' 'migration go/no-go summary' $true @('legacy_project_file_db_dry_run')
    New-Artifact 'legacy_migration_batch_plan' 'json_report' 'scripts/legacy-migration-batch-plan.json' 'migration batch plan' $true @('legacy_migration_readiness_summary')
    New-Artifact 'legacy_migration_batch_db_dry_run' 'json_report' 'scripts/legacy-migration-batch-db-dry-run.json' 'migration batches and items table preview' $true @('legacy_migration_batch_plan')
    New-Artifact 'legacy_record_import_plan' 'json_report' 'scripts/legacy-record-import-plan.json' 'record import plan preview' $true @('legacy_unit_user_db_dry_run', 'legacy_project_db_dry_run', 'legacy_project_file_db_dry_run', 'legacy_migration_batch_db_dry_run')
    New-Artifact 'legacy_migration_blocker_action_sheet' 'json_report' 'scripts/legacy-migration-blocker-action-sheet.json' 'migration blocker action sheet' $true @('legacy_record_import_plan')
    New-Artifact 'legacy_migration_blocker_action_sheet_validation' 'json_report' 'scripts/legacy-migration-blocker-action-sheet-validation.json' 'validation report for migration blocker action sheet' $true @('legacy_migration_blocker_action_sheet')
    New-Artifact 'legacy_migration_blocker_resolution_pack' 'json_report' 'scripts/legacy-migration-blocker-resolution-pack.json' 'blocked stage resolution pack' $true @('legacy_migration_blocker_action_sheet')
    New-Artifact 'legacy_migration_blocker_resolution_pack_csv' 'csv_report' 'scripts/legacy-migration-blocker-resolution-pack.csv' 'blocked stage resolution CSV' $true @('legacy_migration_blocker_resolution_pack')
    New-Artifact 'legacy_migration_blocker_resolution_pack_md' 'markdown_report' 'scripts/legacy-migration-blocker-resolution-pack.md' 'blocked stage resolution markdown' $true @('legacy_migration_blocker_resolution_pack')
    New-Artifact 'legacy_migration_blocker_resolution_pack_validation' 'json_report' 'scripts/legacy-migration-blocker-resolution-pack-validation.json' 'validation report for blocker resolution pack structure' $true @('legacy_migration_blocker_resolution_pack')
    New-Artifact 'legacy_migration_blocker_resolution_signoff' 'json_report' 'scripts/legacy-migration-blocker-resolution-signoff.json' 'manual signoff sheet for blocked stage resolution' $true @('legacy_migration_blocker_resolution_pack')
    New-Artifact 'legacy_migration_blocker_resolution_signoff_csv' 'csv_report' 'scripts/legacy-migration-blocker-resolution-signoff.csv' 'manual signoff CSV for blocked stage resolution' $true @('legacy_migration_blocker_resolution_signoff')
    New-Artifact 'legacy_migration_blocker_resolution_signoff_validation' 'json_report' 'scripts/legacy-migration-blocker-resolution-signoff-validation.json' 'validation report for blocker resolution signoff fields' $true @('legacy_migration_blocker_resolution_signoff')
    New-Artifact 'legacy_migration_blocker_resolution_operator_pack' 'json_report' 'scripts/legacy-migration-blocker-resolution-operator-pack.json' 'operator pack for blocker resolution approval execution verification' $true @('legacy_migration_blocker_resolution_pack', 'legacy_migration_blocker_resolution_signoff', 'legacy_migration_blocker_resolution_signoff_validation')
    New-Artifact 'legacy_migration_blocker_resolution_operator_pack_validation' 'json_report' 'scripts/legacy-migration-blocker-resolution-operator-pack-validation.json' 'validation report for blocker resolution operator pack' $true @('legacy_migration_blocker_resolution_operator_pack')
    New-Artifact 'legacy_migration_resolution_templates' 'json_report' 'scripts/legacy-migration-resolution-templates.json' 'mapping and exception template manifest' $true @('legacy_migration_blocker_action_sheet', 'legacy_attachment_exception_confirmation')
    New-Artifact 'legacy_migration_resolution_validation' 'json_report' 'scripts/legacy-migration-resolution-validation.json' 'mapping and exception template validation report' $true @('legacy_migration_resolution_templates')
    New-Artifact 'legacy_migration_resolution_progress' 'json_report' 'scripts/legacy-migration-resolution-progress.json' 'operator csv mapping completion progress report' $true @('legacy_migration_resolution_validation')
    New-Artifact 'legacy_migration_resolution_worklist' 'json_report' 'scripts/legacy-migration-resolution-worklist.json' 'operator csv mapping worklist report' $true @('legacy_migration_resolution_progress')
    New-Artifact 'legacy_migration_resolution_worklist_csv' 'csv_report' 'scripts/legacy-migration-resolution-worklist.csv' 'operator csv mapping worklist CSV' $true @('legacy_migration_resolution_worklist')
    New-Artifact 'legacy_migration_resolution_row_worklist' 'json_report' 'scripts/legacy-migration-resolution-row-worklist.json' 'row-level operator csv mapping worklist report' $true @('legacy_migration_resolution_worklist')
    New-Artifact 'legacy_migration_resolution_row_worklist_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.csv' 'row-level operator csv mapping worklist CSV' $true @('legacy_migration_resolution_row_worklist')
    New-Artifact 'legacy_migration_resolution_owner_row_worklists' 'json_report' 'scripts/legacy-migration-resolution-owner-row-worklists.json' 'owner-specific row-level mapping worklist report' $true @('legacy_migration_resolution_row_worklist')
    New-Artifact 'legacy_migration_resolution_row_worklist_business_reviewer_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.business_reviewer.csv' 'business reviewer row-level resolution worklist CSV' $true @('legacy_migration_resolution_owner_row_worklists')
    New-Artifact 'legacy_migration_resolution_row_worklist_migration_engineer_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.migration_engineer.csv' 'migration engineer row-level resolution worklist CSV' $true @('legacy_migration_resolution_owner_row_worklists')
    New-Artifact 'legacy_migration_resolution_owner_template_row_worklists' 'json_report' 'scripts/legacy-migration-resolution-owner-template-row-worklists.json' 'owner and template row-level mapping worklist report' $true @('legacy_migration_resolution_owner_row_worklists')
    New-Artifact 'legacy_migration_resolution_row_worklist_business_reviewer_attachment_exceptions_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.business_reviewer.attachment-exceptions.csv' 'business reviewer attachment exception row-level worklist CSV' $true @('legacy_migration_resolution_owner_template_row_worklists')
    New-Artifact 'legacy_migration_resolution_row_worklist_migration_engineer_project_id_map_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.migration_engineer.project-id-map.csv' 'migration engineer project id mapping row-level worklist CSV' $true @('legacy_migration_resolution_owner_template_row_worklists')
    New-Artifact 'legacy_migration_resolution_row_worklist_migration_engineer_unit_user_id_map_csv' 'csv_report' 'scripts/legacy-migration-resolution-row-worklist.migration_engineer.unit-user-id-map.csv' 'migration engineer unit and owner mapping row-level worklist CSV' $true @('legacy_migration_resolution_owner_template_row_worklists')
    New-Artifact 'legacy_migration_resolution_distribution_pack' 'json_report' 'scripts/legacy-migration-resolution-distribution-pack.json' 'distribution manifest for owner-template row worklists' $true @('legacy_migration_resolution_owner_template_row_worklists')
    New-Artifact 'legacy_migration_resolution_distribution_pack_csv' 'csv_report' 'scripts/legacy-migration-resolution-distribution-pack.csv' 'distribution CSV for owner-template row worklists' $true @('legacy_migration_resolution_distribution_pack')
    New-Artifact 'legacy_migration_resolution_distribution_pack_md' 'markdown_report' 'scripts/legacy-migration-resolution-distribution-pack.md' 'distribution instructions for owner-template row worklists' $true @('legacy_migration_resolution_distribution_pack')
    New-Artifact 'legacy_migration_resolution_distribution_pack_zip' 'archive' 'scripts/legacy-migration-resolution-distribution-pack.zip' 'ZIP package for owner-template row worklists' $true @('legacy_migration_resolution_distribution_pack')
    New-Artifact 'legacy_migration_resolution_distribution_signoff' 'json_report' 'scripts/legacy-migration-resolution-distribution-signoff.json' 'manual signoff sheet for resolution distribution handoff' $true @('legacy_migration_resolution_distribution_pack')
    New-Artifact 'legacy_migration_resolution_distribution_signoff_csv' 'csv_report' 'scripts/legacy-migration-resolution-distribution-signoff.csv' 'manual signoff CSV for resolution distribution handoff' $true @('legacy_migration_resolution_distribution_signoff')
    New-Artifact 'legacy_migration_resolution_distribution_signoff_validation' 'json_report' 'scripts/legacy-migration-resolution-distribution-signoff-validation.json' 'validation report for manual distribution signoff fields' $true @('legacy_migration_resolution_distribution_signoff')
    New-Artifact 'legacy_migration_resolution_owner_worklists' 'json_report' 'scripts/legacy-migration-resolution-owner-worklists.json' 'owner-specific operator csv mapping worklist report' $true @('legacy_migration_resolution_row_worklist')
    New-Artifact 'legacy_migration_resolution_worklist_business_reviewer_csv' 'csv_report' 'scripts/legacy-migration-resolution-worklist.business_reviewer.csv' 'business reviewer resolution worklist CSV' $true @('legacy_migration_resolution_owner_worklists')
    New-Artifact 'legacy_migration_resolution_worklist_migration_engineer_csv' 'csv_report' 'scripts/legacy-migration-resolution-worklist.migration_engineer.csv' 'migration engineer resolution worklist CSV' $true @('legacy_migration_resolution_owner_worklists')
    New-Artifact 'legacy_migration_resolution_import_preview' 'json_report' 'scripts/legacy-migration-resolution-import-preview.json' 'operator csv mapping import preview' $true @('legacy_migration_resolution_worklist')
    New-Artifact 'legacy_unit_user_id_map_resolved' 'json_report' 'scripts/legacy-unit-user-id-map.resolved.json' 'operator resolved unit and owner id map preview' $true @('legacy_migration_resolution_import_preview')
    New-Artifact 'legacy_project_id_map_resolved' 'json_report' 'scripts/legacy-project-id-map.resolved.json' 'operator resolved project id map preview' $true @('legacy_migration_resolution_import_preview')
    New-Artifact 'legacy_attachment_exceptions_resolved' 'json_report' 'scripts/legacy-attachment-exceptions.resolved.json' 'operator resolved attachment exceptions preview' $true @('legacy_migration_resolution_import_preview')
    New-Artifact 'legacy_unit_user_db_dry_run_resolved' 'json_report' 'scripts/legacy-unit-user-db-dry-run.resolved.json' 'unit and user import preview using operator resolved map' $true @('legacy_unit_user_id_map_resolved')
    New-Artifact 'legacy_project_db_dry_run_resolved' 'json_report' 'scripts/legacy-project-db-dry-run.resolved.json' 'project import preview using operator resolved map' $true @('legacy_unit_user_id_map_resolved')
    New-Artifact 'legacy_project_file_db_dry_run_resolved' 'json_report' 'scripts/legacy-project-file-db-dry-run.resolved.json' 'project file import preview using operator resolved project map' $true @('legacy_project_id_map_resolved')
    New-Artifact 'legacy_migration_dry_run_comparison' 'json_report' 'scripts/legacy-migration-dry-run-comparison.json' 'default resolved and mock dry-run comparison' $true @('legacy_unit_user_db_dry_run_resolved', 'legacy_project_db_dry_run_resolved', 'legacy_project_file_db_dry_run_resolved')
    New-Artifact 'legacy_migration_resolution_acceptance_gate' 'json_report' 'scripts/legacy-migration-resolution-acceptance-gate.json' 'acceptance gate for operator resolution mappings' $true @('legacy_migration_dry_run_comparison', 'legacy_migration_resolution_worklist')
    New-Artifact 'legacy_migration_resolution_acceptance_gate_csv' 'csv_report' 'scripts/legacy-migration-resolution-acceptance-gate.csv' 'acceptance gate CSV for operator resolution mappings' $true @('legacy_migration_resolution_acceptance_gate')
    New-Artifact 'legacy_migration_resolution_operator_pack' 'json_report' 'scripts/legacy-migration-resolution-operator-pack.json' 'operator pack for resolution mapping workflow' $true @('legacy_migration_resolution_acceptance_gate', 'legacy_migration_resolution_worklist')
    New-Artifact 'legacy_migration_resolution_operator_pack_validation' 'json_report' 'scripts/legacy-migration-resolution-operator-pack-validation.json' 'validation report for resolution mapping operator pack' $true @('legacy_migration_resolution_operator_pack')
    New-Artifact 'legacy_unit_user_id_map_template_csv' 'csv_report' 'scripts/legacy-unit-user-id-map.template.csv' 'unit and owner id mapping csv template' $true @('legacy_migration_resolution_templates')
    New-Artifact 'legacy_project_id_map_template_csv' 'csv_report' 'scripts/legacy-project-id-map.template.csv' 'project id mapping csv template' $true @('legacy_migration_resolution_templates')
    New-Artifact 'legacy_attachment_exceptions_template_csv' 'csv_report' 'scripts/legacy-attachment-exceptions.template.csv' 'attachment exception csv template' $true @('legacy_migration_resolution_templates')
    New-Artifact 'legacy_migration_go_live_drill_report' 'markdown_report' 'scripts/legacy-migration-go-live-drill-report.md' 'go-live drill report template' $true @('legacy_unit_user_id_map_resolved', 'legacy_project_id_map_resolved', 'legacy_attachment_exceptions_resolved', 'legacy_unit_user_db_dry_run_resolved', 'legacy_project_db_dry_run_resolved', 'legacy_project_file_db_dry_run_resolved', 'legacy_migration_dry_run_comparison')
    New-Artifact 'legacy_migration_rollback_plan' 'markdown_report' 'scripts/legacy-migration-rollback-plan.md' 'rollback plan template' $true @('legacy_migration_go_live_drill_report')
    New-Artifact 'legacy_migration_operator_runbook' 'markdown_report' 'scripts/legacy-migration-operator-runbook.md' 'operator runbook' $true @('legacy_migration_rollback_plan')
    New-Artifact 'legacy_migration_go_live_signoff' 'json_report' 'scripts/legacy-migration-go-live-signoff.json' 'final role signoff sheet for go-live' $true @('legacy_migration_operator_runbook')
    New-Artifact 'legacy_migration_go_live_signoff_csv' 'csv_report' 'scripts/legacy-migration-go-live-signoff.csv' 'final role signoff CSV for go-live' $true @('legacy_migration_go_live_signoff')
    New-Artifact 'legacy_migration_go_live_signoff_validation' 'json_report' 'scripts/legacy-migration-go-live-signoff-validation.json' 'validation report for final go-live role signoff' $true @('legacy_migration_go_live_signoff')
    New-Artifact 'legacy_migration_go_live_signoff_operator_pack' 'json_report' 'scripts/legacy-migration-go-live-signoff-operator-pack.json' 'operator pack for final go-live role signoff' $true @('legacy_migration_go_live_signoff', 'legacy_migration_go_live_signoff_validation')
    New-Artifact 'legacy_migration_go_live_signoff_operator_pack_validation' 'json_report' 'scripts/legacy-migration-go-live-signoff-operator-pack-validation.json' 'validation report for final go-live role signoff operator pack' $true @('legacy_migration_go_live_signoff_operator_pack')
    New-Artifact 'legacy_migration_sampling_acceptance_signoff' 'json_report' 'scripts/legacy-migration-sampling-acceptance-signoff.json' 'business sampling acceptance signoff sheet' $true @('legacy_unit_user_db_dry_run', 'legacy_project_db_dry_run', 'legacy_project_file_db_dry_run', 'legacy_workflow_db_dry_run')
    New-Artifact 'legacy_migration_sampling_acceptance_signoff_csv' 'csv_report' 'scripts/legacy-migration-sampling-acceptance-signoff.csv' 'manual business sampling acceptance CSV' $true @('legacy_migration_sampling_acceptance_signoff')
    New-Artifact 'legacy_migration_sampling_acceptance_signoff_validation' 'json_report' 'scripts/legacy-migration-sampling-acceptance-signoff-validation.json' 'validation report for business sampling acceptance fields' $true @('legacy_migration_sampling_acceptance_signoff')
    New-Artifact 'legacy_migration_sampling_acceptance_operator_pack' 'json_report' 'scripts/legacy-migration-sampling-acceptance-operator-pack.json' 'operator pack for business sampling acceptance' $true @('legacy_migration_sampling_acceptance_signoff', 'legacy_migration_sampling_acceptance_signoff_validation')
    New-Artifact 'legacy_migration_sampling_acceptance_operator_pack_validation' 'json_report' 'scripts/legacy-migration-sampling-acceptance-operator-pack-validation.json' 'validation report for business sampling acceptance operator pack' $true @('legacy_migration_sampling_acceptance_operator_pack')
    New-Artifact 'legacy_migration_operational_docs_validation' 'json_report' 'scripts/legacy-migration-operational-docs-validation.json' 'validation report for go-live drill report, rollback plan, and operator runbook' $true @('legacy_migration_go_live_drill_report', 'legacy_migration_rollback_plan', 'legacy_migration_operator_runbook')
    New-Artifact 'legacy_migration_go_live_gate' 'json_report' 'scripts/legacy-migration-go-live-gate.json' 'go-live go/no-go gate report' $true @('legacy_migration_preflight_checklist', 'legacy_migration_resolution_acceptance_gate', 'legacy_migration_go_live_drill_report', 'legacy_migration_rollback_plan', 'legacy_migration_operator_runbook')
    New-Artifact 'legacy_migration_go_live_gate_csv' 'csv_report' 'scripts/legacy-migration-go-live-gate.csv' 'go-live go/no-go gate CSV' $true @('legacy_migration_go_live_gate')
    New-Artifact 'legacy_migration_go_live_gate_validation' 'json_report' 'scripts/legacy-migration-go-live-gate-validation.json' 'validation report for go-live gate structure and calculated readiness' $true @('legacy_migration_go_live_gate')
    New-Artifact 'legacy_migration_artifact_manifest' 'json_report' 'scripts/legacy-migration-artifact-manifest.json' 'artifact completeness manifest' $true @('legacy_migration_go_live_gate')
    New-Artifact 'legacy_migration_artifact_manifest_validation' 'json_report' 'scripts/legacy-migration-artifact-manifest-validation.json' 'validation report for artifact manifest structure and counts' $true @('legacy_migration_artifact_manifest')
    New-Artifact 'legacy_migration_go_live_evidence_pack' 'json_report' 'scripts/legacy-migration-go-live-evidence-pack.json' 'go-live evidence package manifest' $true @('legacy_migration_go_live_gate')
    New-Artifact 'legacy_migration_go_live_evidence_pack_csv' 'csv_report' 'scripts/legacy-migration-go-live-evidence-pack.csv' 'go-live evidence package CSV' $true @('legacy_migration_go_live_evidence_pack')
    New-Artifact 'legacy_migration_go_live_evidence_pack_md' 'markdown_report' 'scripts/legacy-migration-go-live-evidence-pack.md' 'go-live evidence package markdown' $true @('legacy_migration_go_live_evidence_pack')
    New-Artifact 'legacy_migration_go_live_evidence_pack_zip' 'archive' 'scripts/legacy-migration-go-live-evidence-pack.zip' 'go-live evidence package ZIP' $true @('legacy_migration_go_live_evidence_pack')
    New-Artifact 'legacy_migration_go_live_evidence_pack_validation' 'json_report' 'scripts/legacy-migration-go-live-evidence-pack-validation.json' 'validation report for go-live evidence package and ZIP contents' $true @('legacy_migration_go_live_evidence_pack_zip')
    New-Artifact 'legacy_migration_go_live_drill_operator_pack' 'json_report' 'scripts/legacy-migration-go-live-drill-operator-pack.json' 'operator pack for go-live drill readiness' $true @('legacy_migration_go_live_evidence_pack', 'legacy_migration_go_live_signoff_operator_pack', 'legacy_migration_preflight_checklist')
    New-Artifact 'legacy_migration_go_live_drill_operator_pack_validation' 'json_report' 'scripts/legacy-migration-go-live-drill-operator-pack-validation.json' 'validation report for go-live drill operator pack' $true @('legacy_migration_go_live_drill_operator_pack')
    New-Artifact 'legacy_migration_next_actions' 'json_report' 'scripts/legacy-migration-next-actions.json' 'prioritized next actions report' $true @('legacy_migration_preflight_checklist', 'legacy_migration_go_live_gate', 'legacy_migration_go_live_evidence_pack')
    New-Artifact 'legacy_migration_next_actions_csv' 'csv_report' 'scripts/legacy-migration-next-actions.csv' 'prioritized next actions CSV' $true @('legacy_migration_next_actions')
    New-Artifact 'legacy_migration_next_actions_md' 'markdown_report' 'scripts/legacy-migration-next-actions.md' 'prioritized next actions markdown' $true @('legacy_migration_next_actions')
    New-Artifact 'legacy_migration_next_actions_blockers_csv' 'csv_report' 'scripts/legacy-migration-next-actions.blockers.csv' 'blocker-only next actions CSV' $true @('legacy_migration_next_actions')
    New-Artifact 'legacy_migration_next_actions_blockers_md' 'markdown_report' 'scripts/legacy-migration-next-actions.blockers.md' 'blocker-only next actions markdown' $true @('legacy_migration_next_actions')
    New-Artifact 'legacy_migration_next_actions_validation' 'json_report' 'scripts/legacy-migration-next-actions-validation.json' 'validation report for prioritized next actions report' $true @('legacy_migration_next_actions', 'legacy_migration_next_actions_csv', 'legacy_migration_next_actions_md', 'legacy_migration_next_actions_blockers_csv', 'legacy_migration_next_actions_blockers_md')
    New-Artifact 'legacy_migration_next_actions_owner_files' 'json_report' 'scripts/legacy-migration-next-actions.owner-files.json' 'owner-specific next action file manifest' $true @('legacy_migration_next_actions')
    New-Artifact 'legacy_migration_next_actions_owner_files_zip' 'archive' 'scripts/legacy-migration-next-actions.owner-files.zip' 'ZIP package for owner-specific next action files' $true @('legacy_migration_next_actions_owner_files')
    New-Artifact 'legacy_migration_next_actions_owner_files_validation' 'json_report' 'scripts/legacy-migration-next-actions.owner-files-validation.json' 'validation report for owner-specific next action files and ZIP contents' $true @('legacy_migration_next_actions_owner_files_zip')
    New-Artifact 'legacy_migration_next_actions_owner_signoff' 'json_report' 'scripts/legacy-migration-next-actions.owner-signoff.json' 'manual signoff sheet for owner-specific next action handoff' $true @('legacy_migration_next_actions_owner_files')
    New-Artifact 'legacy_migration_next_actions_owner_signoff_csv' 'csv_report' 'scripts/legacy-migration-next-actions.owner-signoff.csv' 'manual signoff CSV for owner-specific next action handoff' $true @('legacy_migration_next_actions_owner_signoff')
    New-Artifact 'legacy_migration_next_actions_owner_signoff_validation' 'json_report' 'scripts/legacy-migration-next-actions.owner-signoff-validation.json' 'validation report for owner-specific next action handoff signoff fields' $true @('legacy_migration_next_actions_owner_signoff')
    New-Artifact 'legacy_migration_next_actions_owner_signoff_operator_pack' 'json_report' 'scripts/legacy-migration-next-actions.owner-signoff-operator-pack.json' 'operator pack for owner-specific next action handoff signoff' $true @('legacy_migration_next_actions_owner_signoff', 'legacy_migration_next_actions_owner_signoff_validation')
    New-Artifact 'legacy_migration_next_actions_owner_signoff_operator_pack_validation' 'json_report' 'scripts/legacy-migration-next-actions.owner-signoff-operator-pack-validation.json' 'validation report for owner-specific next action handoff signoff operator pack' $true @('legacy_migration_next_actions_owner_signoff_operator_pack')
    New-Artifact 'legacy_migration_preflight_checklist' 'json_report' 'scripts/legacy-migration-preflight-checklist.json' 'preflight checklist' $true @('legacy_migration_batch_db_dry_run', 'legacy_record_import_plan', 'legacy_migration_blocker_action_sheet', 'legacy_unit_user_id_map_resolved', 'legacy_project_id_map_resolved', 'legacy_attachment_exceptions_resolved', 'legacy_unit_user_db_dry_run_resolved', 'legacy_project_db_dry_run_resolved', 'legacy_project_file_db_dry_run_resolved', 'legacy_migration_dry_run_comparison')
    New-Artifact 'legacy_migration_preflight_checklist_validation' 'json_report' 'scripts/legacy-migration-preflight-checklist-validation.json' 'validation report for preflight checklist structure and calculated readiness' $true @('legacy_migration_preflight_checklist')
    New-Artifact 'legacy_migration_preflight_blocker_operator_pack' 'json_report' 'scripts/legacy-migration-preflight-blocker-operator-pack.json' 'operator pack for preflight blockers and warnings' $true @('legacy_migration_preflight_checklist')
    New-Artifact 'legacy_migration_preflight_blocker_operator_pack_validation' 'json_report' 'scripts/legacy-migration-preflight-blocker-operator-pack-validation.json' 'validation report for preflight blocker operator pack' $true @('legacy_migration_preflight_blocker_operator_pack')
    New-Artifact 'legacy_migration_preflight_blocker_operator_pack_csv' 'csv_report' 'scripts/legacy-migration-preflight-blocker-operator-pack.csv' 'CSV version of preflight blocker operator pack' $true @('legacy_migration_preflight_blocker_operator_pack')
    New-Artifact 'legacy_migration_preflight_blocker_operator_pack_md' 'markdown_report' 'scripts/legacy-migration-preflight-blocker-operator-pack.md' 'Markdown version of preflight blocker operator pack' $true @('legacy_migration_preflight_blocker_operator_pack')

    New-Artifact 'field_mapping_doc' 'doc' 'docs/field-mapping.md' 'field mapping document' $true
    New-Artifact 'acceptance_checklist_doc' 'doc' 'docs/acceptance-checklist.md' 'acceptance checklist document' $true
    New-Artifact 'migration_pipeline_doc' 'doc' 'docs/migration-report-pipeline.md' 'migration report pipeline document' $true
    New-Artifact 'migration_pipeline_script' 'script' 'scripts/Invoke-LegacyMigrationReportPipeline.ps1' 'migration report pipeline entrypoint' $true
)

$nextActionsOwnerFiles = Read-JsonReport (Join-Path $PSScriptRoot 'legacy-migration-next-actions.owner-files.json')
foreach ($ownerFile in @($nextActionsOwnerFiles.files)) {
    $slug = Get-ArtifactKeyToken $ownerFile.slug
    $owner = if ([string]::IsNullOrWhiteSpace([string]$ownerFile.owner)) { $slug } else { [string]$ownerFile.owner }

    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.csv)) {
        $artifacts += New-Artifact "legacy_migration_next_actions_owner_${slug}_csv" 'csv_report' $ownerFile.csv "owner-specific next actions CSV for $owner" $true @('legacy_migration_next_actions_owner_files')
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.markdown)) {
        $artifacts += New-Artifact "legacy_migration_next_actions_owner_${slug}_md" 'markdown_report' $ownerFile.markdown "owner-specific next actions markdown for $owner" $true @('legacy_migration_next_actions_owner_files')
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.blocker_csv)) {
        $artifacts += New-Artifact "legacy_migration_next_actions_owner_${slug}_blockers_csv" 'csv_report' $ownerFile.blocker_csv "owner-specific blocker actions CSV for $owner" $true @('legacy_migration_next_actions_owner_files')
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$ownerFile.blocker_markdown)) {
        $artifacts += New-Artifact "legacy_migration_next_actions_owner_${slug}_blockers_md" 'markdown_report' $ownerFile.blocker_markdown "owner-specific blocker actions markdown for $owner" $true @('legacy_migration_next_actions_owner_files')
    }
}

$requiredArtifacts = @($artifacts | Where-Object { $_.required })
$missingRequired = @($requiredArtifacts | Where-Object { -not $_.exists })
$missingOptional = @($artifacts | Where-Object { -not $_.required -and -not $_.exists })

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    root = $Root
    summary = [ordered]@{
        total_artifacts = $artifacts.Count
        required_artifacts = $requiredArtifacts.Count
        existing_artifacts = @($artifacts | Where-Object { $_.exists }).Count
        missing_required = $missingRequired.Count
        missing_optional = $missingOptional.Count
    }
    missing_required = @($missingRequired | ForEach-Object { $_.key })
    missing_optional = @($missingOptional | ForEach-Object { $_.key })
    artifacts = @($artifacts)
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration artifact manifest written to $ReportPath"



