<?php

namespace App\Http\Controllers;

use App\Support\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;

class MigrationReadinessController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        if (! Role::userCan($request->user(), 'view_migration')) {
            abort(403, '无权查看迁移准备');
        }

        $root = base_path('..');
        $reports = [
            'legacy_table_report' => $root.'/scripts/legacy-core-tables.txt',
            'legacy_risk_report' => $root.'/scripts/legacy-risk-report.txt',
            'legacy_security_baseline_operator_pack' => $root.'/scripts/legacy-security-baseline-operator-pack.json',
            'legacy_security_baseline_operator_pack_validation' => $root.'/scripts/legacy-security-baseline-operator-pack-validation.json',
            'legacy_security_baseline_signoff' => $root.'/scripts/legacy-security-baseline-signoff.json',
            'legacy_security_baseline_signoff_validation' => $root.'/scripts/legacy-security-baseline-signoff-validation.json',
            'legacy_security_public_executable_worklist' => $root.'/scripts/legacy-security-public-executable-worklist.json',
            'legacy_security_public_executable_worklist_validation' => $root.'/scripts/legacy-security-public-executable-worklist-validation.json',
            'legacy_security_public_executable_remediation_plan' => $root.'/scripts/legacy-security-public-executable-remediation-plan.json',
            'legacy_security_public_executable_remediation_plan_validation' => $root.'/scripts/legacy-security-public-executable-remediation-plan-validation.json',
            'legacy_security_public_executable_remediation_wave_files' => $root.'/scripts/legacy-security-public-executable-remediation-wave-files.json',
            'legacy_security_public_executable_remediation_wave_files_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-files-validation.json',
            'legacy_security_public_executable_remediation_wave_signoff' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff.json',
            'legacy_security_public_executable_remediation_wave_signoff_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-validation.json',
            'legacy_security_public_executable_remediation_wave_signoff_operator_pack' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-operator-pack.json',
            'legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-operator-pack-validation.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_pack' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-pack-validation.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-validation.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json',
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' => $root.'/scripts/legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack-validation.json',
            'legacy_import_dry_run' => $root.'/scripts/legacy-import-dry-run.json',
            'legacy_migration_preview' => $root.'/scripts/legacy-migration-preview.json',
            'legacy_attachment_quality' => $root.'/scripts/legacy-attachment-quality.json',
            'legacy_attachment_import_index' => $root.'/scripts/legacy-attachment-import-index.json',
            'legacy_attachment_import_dry_run' => $root.'/scripts/legacy-attachment-import-dry-run.json',
            'legacy_attachment_exception_confirmation' => $root.'/scripts/legacy-attachment-exception-confirmation.json',
            'legacy_attachment_exception_worksheet' => $root.'/scripts/legacy-attachment-exception-worksheet.json',
            'legacy_attachment_exception_worksheet_import_preview' => $root.'/scripts/legacy-attachment-exception-worksheet-import-preview.json',
            'legacy_attachment_exception_template_patch_preview' => $root.'/scripts/legacy-attachment-exception-template-patch-preview.json',
            'legacy_attachment_exception_operator_pack' => $root.'/scripts/legacy-attachment-exception-operator-pack.json',
            'legacy_attachment_exception_operator_pack_validation' => $root.'/scripts/legacy-attachment-exception-operator-pack-validation.json',
            'legacy_attachment_import_execute' => $root.'/scripts/legacy-attachment-import-execute.json',
            'legacy_project_id_map' => $root.'/scripts/legacy-project-id-map.json',
            'legacy_project_id_map_mock' => $root.'/scripts/legacy-project-id-map.mock.json',
            'legacy_project_id_map_resolved' => $root.'/scripts/legacy-project-id-map.resolved.json',
            'legacy_unit_user_id_map' => $root.'/scripts/legacy-unit-user-id-map.json',
            'legacy_unit_user_id_map_mock' => $root.'/scripts/legacy-unit-user-id-map.mock.json',
            'legacy_unit_user_id_map_resolved' => $root.'/scripts/legacy-unit-user-id-map.resolved.json',
            'legacy_unit_user_db_dry_run' => $root.'/scripts/legacy-unit-user-db-dry-run.json',
            'legacy_unit_user_db_dry_run_mock' => $root.'/scripts/legacy-unit-user-db-dry-run.mock.json',
            'legacy_unit_user_db_dry_run_resolved' => $root.'/scripts/legacy-unit-user-db-dry-run.resolved.json',
            'legacy_project_db_dry_run' => $root.'/scripts/legacy-project-db-dry-run.json',
            'legacy_project_db_dry_run_mock' => $root.'/scripts/legacy-project-db-dry-run.mock.json',
            'legacy_project_db_dry_run_resolved' => $root.'/scripts/legacy-project-db-dry-run.resolved.json',
            'legacy_project_file_db_dry_run' => $root.'/scripts/legacy-project-file-db-dry-run.json',
            'legacy_project_file_db_dry_run_mock' => $root.'/scripts/legacy-project-file-db-dry-run.mock.json',
            'legacy_project_file_db_dry_run_resolved' => $root.'/scripts/legacy-project-file-db-dry-run.resolved.json',
            'legacy_workflow_db_dry_run' => $root.'/scripts/legacy-workflow-db-dry-run.json',
            'legacy_workflow_db_dry_run_mock' => $root.'/scripts/legacy-workflow-db-dry-run.mock.json',
            'legacy_workflow_orphan_resolution_signoff' => $root.'/scripts/legacy-workflow-orphan-resolution-signoff.json',
            'legacy_workflow_orphan_resolution_signoff_validation' => $root.'/scripts/legacy-workflow-orphan-resolution-signoff-validation.json',
            'legacy_workflow_orphan_operator_pack' => $root.'/scripts/legacy-workflow-orphan-operator-pack.json',
            'legacy_workflow_orphan_operator_pack_validation' => $root.'/scripts/legacy-workflow-orphan-operator-pack-validation.json',
            'legacy_migration_dry_run_comparison' => $root.'/scripts/legacy-migration-dry-run-comparison.json',
            'legacy_migration_resolution_acceptance_gate' => $root.'/scripts/legacy-migration-resolution-acceptance-gate.json',
            'legacy_migration_resolution_operator_pack' => $root.'/scripts/legacy-migration-resolution-operator-pack.json',
            'legacy_migration_resolution_operator_pack_validation' => $root.'/scripts/legacy-migration-resolution-operator-pack-validation.json',
            'legacy_migration_readiness_summary' => $root.'/scripts/legacy-migration-readiness-summary.json',
            'legacy_migration_batch_plan' => $root.'/scripts/legacy-migration-batch-plan.json',
            'legacy_migration_batch_db_dry_run' => $root.'/scripts/legacy-migration-batch-db-dry-run.json',
            'legacy_record_import_plan' => $root.'/scripts/legacy-record-import-plan.json',
            'legacy_migration_blocker_action_sheet' => $root.'/scripts/legacy-migration-blocker-action-sheet.json',
            'legacy_migration_blocker_action_sheet_validation' => $root.'/scripts/legacy-migration-blocker-action-sheet-validation.json',
            'legacy_migration_blocker_resolution_pack' => $root.'/scripts/legacy-migration-blocker-resolution-pack.json',
            'legacy_migration_blocker_resolution_pack_validation' => $root.'/scripts/legacy-migration-blocker-resolution-pack-validation.json',
            'legacy_migration_blocker_resolution_signoff' => $root.'/scripts/legacy-migration-blocker-resolution-signoff.json',
            'legacy_migration_blocker_resolution_signoff_validation' => $root.'/scripts/legacy-migration-blocker-resolution-signoff-validation.json',
            'legacy_migration_blocker_resolution_operator_pack' => $root.'/scripts/legacy-migration-blocker-resolution-operator-pack.json',
            'legacy_migration_blocker_resolution_operator_pack_validation' => $root.'/scripts/legacy-migration-blocker-resolution-operator-pack-validation.json',
            'legacy_migration_resolution_templates' => $root.'/scripts/legacy-migration-resolution-templates.json',
            'legacy_migration_resolution_validation' => $root.'/scripts/legacy-migration-resolution-validation.json',
            'legacy_migration_resolution_progress' => $root.'/scripts/legacy-migration-resolution-progress.json',
            'legacy_migration_resolution_worklist' => $root.'/scripts/legacy-migration-resolution-worklist.json',
            'legacy_migration_resolution_row_worklist' => $root.'/scripts/legacy-migration-resolution-row-worklist.json',
            'legacy_migration_resolution_owner_row_worklists' => $root.'/scripts/legacy-migration-resolution-owner-row-worklists.json',
            'legacy_migration_resolution_owner_template_row_worklists' => $root.'/scripts/legacy-migration-resolution-owner-template-row-worklists.json',
            'legacy_migration_resolution_distribution_pack' => $root.'/scripts/legacy-migration-resolution-distribution-pack.json',
            'legacy_migration_resolution_distribution_signoff' => $root.'/scripts/legacy-migration-resolution-distribution-signoff.json',
            'legacy_migration_resolution_distribution_signoff_validation' => $root.'/scripts/legacy-migration-resolution-distribution-signoff-validation.json',
            'legacy_migration_resolution_owner_worklists' => $root.'/scripts/legacy-migration-resolution-owner-worklists.json',
            'legacy_migration_resolution_import_preview' => $root.'/scripts/legacy-migration-resolution-import-preview.json',
            'legacy_attachment_exceptions_resolved' => $root.'/scripts/legacy-attachment-exceptions.resolved.json',
            'legacy_migration_artifact_manifest' => $root.'/scripts/legacy-migration-artifact-manifest.json',
            'legacy_migration_artifact_manifest_validation' => $root.'/scripts/legacy-migration-artifact-manifest-validation.json',
            'legacy_migration_preflight_checklist' => $root.'/scripts/legacy-migration-preflight-checklist.json',
            'legacy_migration_preflight_checklist_validation' => $root.'/scripts/legacy-migration-preflight-checklist-validation.json',
            'legacy_migration_preflight_blocker_operator_pack' => $root.'/scripts/legacy-migration-preflight-blocker-operator-pack.json',
            'legacy_migration_preflight_blocker_operator_pack_validation' => $root.'/scripts/legacy-migration-preflight-blocker-operator-pack-validation.json',
            'legacy_migration_go_live_gate' => $root.'/scripts/legacy-migration-go-live-gate.json',
            'legacy_migration_go_live_gate_validation' => $root.'/scripts/legacy-migration-go-live-gate-validation.json',
            'legacy_migration_go_live_signoff' => $root.'/scripts/legacy-migration-go-live-signoff.json',
            'legacy_migration_go_live_signoff_validation' => $root.'/scripts/legacy-migration-go-live-signoff-validation.json',
            'legacy_migration_go_live_signoff_operator_pack' => $root.'/scripts/legacy-migration-go-live-signoff-operator-pack.json',
            'legacy_migration_go_live_signoff_operator_pack_validation' => $root.'/scripts/legacy-migration-go-live-signoff-operator-pack-validation.json',
            'legacy_migration_sampling_acceptance_signoff' => $root.'/scripts/legacy-migration-sampling-acceptance-signoff.json',
            'legacy_migration_sampling_acceptance_signoff_validation' => $root.'/scripts/legacy-migration-sampling-acceptance-signoff-validation.json',
            'legacy_migration_sampling_acceptance_operator_pack' => $root.'/scripts/legacy-migration-sampling-acceptance-operator-pack.json',
            'legacy_migration_sampling_acceptance_operator_pack_validation' => $root.'/scripts/legacy-migration-sampling-acceptance-operator-pack-validation.json',
            'legacy_migration_go_live_evidence_pack' => $root.'/scripts/legacy-migration-go-live-evidence-pack.json',
            'legacy_migration_go_live_evidence_pack_validation' => $root.'/scripts/legacy-migration-go-live-evidence-pack-validation.json',
            'legacy_migration_next_actions' => $root.'/scripts/legacy-migration-next-actions.json',
            'legacy_migration_next_actions_validation' => $root.'/scripts/legacy-migration-next-actions-validation.json',
            'legacy_migration_next_actions_owner_files_validation' => $root.'/scripts/legacy-migration-next-actions.owner-files-validation.json',
            'legacy_migration_next_actions_owner_signoff' => $root.'/scripts/legacy-migration-next-actions.owner-signoff.json',
            'legacy_migration_next_actions_owner_signoff_validation' => $root.'/scripts/legacy-migration-next-actions.owner-signoff-validation.json',
            'legacy_migration_next_actions_owner_signoff_operator_pack' => $root.'/scripts/legacy-migration-next-actions.owner-signoff-operator-pack.json',
            'legacy_migration_next_actions_owner_signoff_operator_pack_validation' => $root.'/scripts/legacy-migration-next-actions.owner-signoff-operator-pack-validation.json',
            'legacy_migration_go_live_drill_report' => $root.'/scripts/legacy-migration-go-live-drill-report.md',
            'legacy_migration_go_live_drill_operator_pack' => $root.'/scripts/legacy-migration-go-live-drill-operator-pack.json',
            'legacy_migration_go_live_drill_operator_pack_validation' => $root.'/scripts/legacy-migration-go-live-drill-operator-pack-validation.json',
            'legacy_migration_operational_docs_validation' => $root.'/scripts/legacy-migration-operational-docs-validation.json',
            'legacy_migration_rollback_plan' => $root.'/scripts/legacy-migration-rollback-plan.md',
            'legacy_migration_operator_runbook' => $root.'/scripts/legacy-migration-operator-runbook.md',
            'legacy_migration_report_pipeline' => $root.'/scripts/Invoke-LegacyMigrationReportPipeline.ps1',
            'table_map' => $root.'/docs/legacy-table-map.md',
            'field_map' => $root.'/docs/field-mapping.md',
            'acceptance_checklist' => $root.'/docs/acceptance-checklist.md',
        ];

        $items = [];
        foreach ($reports as $key => $path) {
            $items[] = [
                'key' => $key,
                'path' => $path,
                'exists' => File::exists($path),
                'updated_at' => File::exists($path) ? date('c', File::lastModified($path)) : null,
            ];
        }

        $dryRunPath = $reports['legacy_import_dry_run'];
        $previewPath = $reports['legacy_migration_preview'];
        $attachmentQualityPath = $reports['legacy_attachment_quality'];
        $attachmentImportIndexPath = $reports['legacy_attachment_import_index'];
        $attachmentImportDryRunPath = $reports['legacy_attachment_import_dry_run'];
        $attachmentExceptionConfirmationPath = $reports['legacy_attachment_exception_confirmation'];
        $attachmentExceptionWorksheetPath = $reports['legacy_attachment_exception_worksheet'];
        $attachmentExceptionWorksheetImportPreviewPath = $reports['legacy_attachment_exception_worksheet_import_preview'];
        $attachmentExceptionTemplatePatchPreviewPath = $reports['legacy_attachment_exception_template_patch_preview'];
        $attachmentExceptionOperatorPackPath = $reports['legacy_attachment_exception_operator_pack'];
        $attachmentExceptionOperatorPackValidationPath = $reports['legacy_attachment_exception_operator_pack_validation'];
        $attachmentImportExecutePath = $reports['legacy_attachment_import_execute'];
        $projectIdMapPath = $reports['legacy_project_id_map'];
        $projectIdMapMockPath = $reports['legacy_project_id_map_mock'];
        $projectIdMapResolvedPath = $reports['legacy_project_id_map_resolved'];
        $unitUserIdMapPath = $reports['legacy_unit_user_id_map'];
        $unitUserIdMapMockPath = $reports['legacy_unit_user_id_map_mock'];
        $unitUserIdMapResolvedPath = $reports['legacy_unit_user_id_map_resolved'];
        $unitUserDbDryRunPath = $reports['legacy_unit_user_db_dry_run'];
        $unitUserDbDryRunMockPath = $reports['legacy_unit_user_db_dry_run_mock'];
        $unitUserDbDryRunResolvedPath = $reports['legacy_unit_user_db_dry_run_resolved'];
        $projectDbDryRunPath = $reports['legacy_project_db_dry_run'];
        $projectDbDryRunMockPath = $reports['legacy_project_db_dry_run_mock'];
        $projectDbDryRunResolvedPath = $reports['legacy_project_db_dry_run_resolved'];
        $projectFileDbDryRunPath = $reports['legacy_project_file_db_dry_run'];
        $projectFileDbDryRunMockPath = $reports['legacy_project_file_db_dry_run_mock'];
        $projectFileDbDryRunResolvedPath = $reports['legacy_project_file_db_dry_run_resolved'];
        $workflowDbDryRunPath = $reports['legacy_workflow_db_dry_run'];
        $workflowDbDryRunMockPath = $reports['legacy_workflow_db_dry_run_mock'];
        $workflowOrphanResolutionSignoffPath = $reports['legacy_workflow_orphan_resolution_signoff'];
        $workflowOrphanResolutionSignoffValidationPath = $reports['legacy_workflow_orphan_resolution_signoff_validation'];
        $workflowOrphanOperatorPackPath = $reports['legacy_workflow_orphan_operator_pack'];
        $workflowOrphanOperatorPackValidationPath = $reports['legacy_workflow_orphan_operator_pack_validation'];
        $migrationDryRunComparisonPath = $reports['legacy_migration_dry_run_comparison'];
        $migrationResolutionAcceptanceGatePath = $reports['legacy_migration_resolution_acceptance_gate'];
        $migrationResolutionOperatorPackPath = $reports['legacy_migration_resolution_operator_pack'];
        $migrationResolutionOperatorPackValidationPath = $reports['legacy_migration_resolution_operator_pack_validation'];
        $migrationReadinessSummaryPath = $reports['legacy_migration_readiness_summary'];
        $migrationBatchPlanPath = $reports['legacy_migration_batch_plan'];
        $migrationBatchDbDryRunPath = $reports['legacy_migration_batch_db_dry_run'];
        $recordImportPlanPath = $reports['legacy_record_import_plan'];
        $migrationBlockerActionSheetPath = $reports['legacy_migration_blocker_action_sheet'];
        $migrationBlockerActionSheetValidationPath = $reports['legacy_migration_blocker_action_sheet_validation'];
        $migrationBlockerResolutionPackPath = $reports['legacy_migration_blocker_resolution_pack'];
        $migrationBlockerResolutionPackValidationPath = $reports['legacy_migration_blocker_resolution_pack_validation'];
        $migrationBlockerResolutionSignoffPath = $reports['legacy_migration_blocker_resolution_signoff'];
        $migrationBlockerResolutionSignoffValidationPath = $reports['legacy_migration_blocker_resolution_signoff_validation'];
        $migrationBlockerResolutionOperatorPackPath = $reports['legacy_migration_blocker_resolution_operator_pack'];
        $migrationBlockerResolutionOperatorPackValidationPath = $reports['legacy_migration_blocker_resolution_operator_pack_validation'];
        $migrationResolutionTemplatesPath = $reports['legacy_migration_resolution_templates'];
        $migrationResolutionValidationPath = $reports['legacy_migration_resolution_validation'];
        $migrationResolutionProgressPath = $reports['legacy_migration_resolution_progress'];
        $migrationResolutionWorklistPath = $reports['legacy_migration_resolution_worklist'];
        $migrationResolutionRowWorklistPath = $reports['legacy_migration_resolution_row_worklist'];
        $migrationResolutionOwnerRowWorklistsPath = $reports['legacy_migration_resolution_owner_row_worklists'];
        $migrationResolutionOwnerTemplateRowWorklistsPath = $reports['legacy_migration_resolution_owner_template_row_worklists'];
        $migrationResolutionDistributionPackPath = $reports['legacy_migration_resolution_distribution_pack'];
        $migrationResolutionDistributionSignoffPath = $reports['legacy_migration_resolution_distribution_signoff'];
        $migrationResolutionDistributionSignoffValidationPath = $reports['legacy_migration_resolution_distribution_signoff_validation'];
        $migrationResolutionOwnerWorklistsPath = $reports['legacy_migration_resolution_owner_worklists'];
        $migrationResolutionImportPreviewPath = $reports['legacy_migration_resolution_import_preview'];
        $attachmentExceptionsResolvedPath = $reports['legacy_attachment_exceptions_resolved'];
        $migrationArtifactManifestPath = $reports['legacy_migration_artifact_manifest'];
        $migrationArtifactManifestValidationPath = $reports['legacy_migration_artifact_manifest_validation'];
        $migrationPreflightChecklistPath = $reports['legacy_migration_preflight_checklist'];
        $migrationPreflightChecklistValidationPath = $reports['legacy_migration_preflight_checklist_validation'];
        $migrationPreflightBlockerOperatorPackPath = $reports['legacy_migration_preflight_blocker_operator_pack'];
        $migrationPreflightBlockerOperatorPackValidationPath = $reports['legacy_migration_preflight_blocker_operator_pack_validation'];
        $migrationGoLiveGatePath = $reports['legacy_migration_go_live_gate'];
        $migrationGoLiveGateValidationPath = $reports['legacy_migration_go_live_gate_validation'];
        $migrationGoLiveSignoffPath = $reports['legacy_migration_go_live_signoff'];
        $migrationGoLiveSignoffValidationPath = $reports['legacy_migration_go_live_signoff_validation'];
        $migrationGoLiveSignoffOperatorPackPath = $reports['legacy_migration_go_live_signoff_operator_pack'];
        $migrationGoLiveSignoffOperatorPackValidationPath = $reports['legacy_migration_go_live_signoff_operator_pack_validation'];
        $migrationSamplingAcceptanceSignoffPath = $reports['legacy_migration_sampling_acceptance_signoff'];
        $migrationSamplingAcceptanceSignoffValidationPath = $reports['legacy_migration_sampling_acceptance_signoff_validation'];
        $migrationSamplingAcceptanceOperatorPackPath = $reports['legacy_migration_sampling_acceptance_operator_pack'];
        $migrationSamplingAcceptanceOperatorPackValidationPath = $reports['legacy_migration_sampling_acceptance_operator_pack_validation'];
        $migrationGoLiveEvidencePackPath = $reports['legacy_migration_go_live_evidence_pack'];
        $migrationGoLiveEvidencePackValidationPath = $reports['legacy_migration_go_live_evidence_pack_validation'];
        $migrationGoLiveDrillOperatorPackPath = $reports['legacy_migration_go_live_drill_operator_pack'];
        $migrationGoLiveDrillOperatorPackValidationPath = $reports['legacy_migration_go_live_drill_operator_pack_validation'];
        $migrationOperationalDocsValidationPath = $reports['legacy_migration_operational_docs_validation'];
        $securityBaselineOperatorPackPath = $reports['legacy_security_baseline_operator_pack'];
        $securityBaselineOperatorPackValidationPath = $reports['legacy_security_baseline_operator_pack_validation'];
        $securityBaselineSignoffPath = $reports['legacy_security_baseline_signoff'];
        $securityBaselineSignoffValidationPath = $reports['legacy_security_baseline_signoff_validation'];
        $securityPublicExecutableWorklistPath = $reports['legacy_security_public_executable_worklist'];
        $securityPublicExecutableWorklistValidationPath = $reports['legacy_security_public_executable_worklist_validation'];
        $securityPublicExecutableRemediationPlanPath = $reports['legacy_security_public_executable_remediation_plan'];
        $securityPublicExecutableRemediationPlanValidationPath = $reports['legacy_security_public_executable_remediation_plan_validation'];
        $securityPublicExecutableRemediationWaveFilesPath = $reports['legacy_security_public_executable_remediation_wave_files'];
        $securityPublicExecutableRemediationWaveFilesValidationPath = $reports['legacy_security_public_executable_remediation_wave_files_validation'];
        $securityPublicExecutableRemediationWaveSignoffPath = $reports['legacy_security_public_executable_remediation_wave_signoff'];
        $securityPublicExecutableRemediationWaveSignoffValidationPath = $reports['legacy_security_public_executable_remediation_wave_signoff_validation'];
        $securityPublicExecutableRemediationWaveSignoffOperatorPackPath = $reports['legacy_security_public_executable_remediation_wave_signoff_operator_pack'];
        $securityPublicExecutableRemediationWaveSignoffOperatorPackValidationPath = $reports['legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation'];
        $securityPublicExecutableRemediationWaveSignoffHandoffPackPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_pack'];
        $securityPublicExecutableRemediationWaveSignoffHandoffPackValidationPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation'];
        $securityPublicExecutableRemediationWaveSignoffHandoffSignoffPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_signoff'];
        $securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidationPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation'];
        $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack'];
        $securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath = $reports['legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation'];
        $migrationNextActionsPath = $reports['legacy_migration_next_actions'];
        $migrationNextActionsValidationPath = $reports['legacy_migration_next_actions_validation'];
        $migrationNextActionsOwnerFilesValidationPath = $reports['legacy_migration_next_actions_owner_files_validation'];
        $migrationNextActionsOwnerSignoffPath = $reports['legacy_migration_next_actions_owner_signoff'];
        $migrationNextActionsOwnerSignoffValidationPath = $reports['legacy_migration_next_actions_owner_signoff_validation'];
        $migrationNextActionsOwnerSignoffOperatorPackPath = $reports['legacy_migration_next_actions_owner_signoff_operator_pack'];
        $migrationNextActionsOwnerSignoffOperatorPackValidationPath = $reports['legacy_migration_next_actions_owner_signoff_operator_pack_validation'];
        $migrationGoLiveGate = File::exists($migrationGoLiveGatePath)
            ? json_decode(File::get($migrationGoLiveGatePath), true)
            : null;
        $writeCutoverReady = is_array($migrationGoLiveGate)
            && ($migrationGoLiveGate['overall_status'] ?? null) === 'ready'
            && ($migrationGoLiveGate['write_cutover_ready'] ?? false) === true;

        return response()->json([
            'mode' => 'legacy_new_parallel',
            'write_cutover_ready' => $writeCutoverReady,
            'items' => $items,
            'dry_run' => File::exists($dryRunPath)
                ? json_decode(File::get($dryRunPath), true)
                : null,
            'preview' => File::exists($previewPath)
                ? json_decode(File::get($previewPath), true)
                : null,
            'attachment_quality' => File::exists($attachmentQualityPath)
                ? json_decode(File::get($attachmentQualityPath), true)
                : null,
            'attachment_import_index' => File::exists($attachmentImportIndexPath)
                ? json_decode(File::get($attachmentImportIndexPath), true)
                : null,
            'attachment_import_dry_run' => File::exists($attachmentImportDryRunPath)
                ? json_decode(File::get($attachmentImportDryRunPath), true)
                : null,
            'attachment_exception_confirmation' => File::exists($attachmentExceptionConfirmationPath)
                ? json_decode(File::get($attachmentExceptionConfirmationPath), true)
                : null,
            'attachment_exception_worksheet' => File::exists($attachmentExceptionWorksheetPath)
                ? json_decode(File::get($attachmentExceptionWorksheetPath), true)
                : null,
            'attachment_exception_worksheet_import_preview' => File::exists($attachmentExceptionWorksheetImportPreviewPath)
                ? json_decode(File::get($attachmentExceptionWorksheetImportPreviewPath), true)
                : null,
            'attachment_exception_template_patch_preview' => File::exists($attachmentExceptionTemplatePatchPreviewPath)
                ? json_decode(File::get($attachmentExceptionTemplatePatchPreviewPath), true)
                : null,
            'attachment_exception_operator_pack' => File::exists($attachmentExceptionOperatorPackPath)
                ? json_decode(File::get($attachmentExceptionOperatorPackPath), true)
                : null,
            'attachment_exception_operator_pack_validation' => File::exists($attachmentExceptionOperatorPackValidationPath)
                ? json_decode(File::get($attachmentExceptionOperatorPackValidationPath), true)
                : null,
            'attachment_import_execute' => File::exists($attachmentImportExecutePath)
                ? json_decode(File::get($attachmentImportExecutePath), true)
                : null,
            'project_id_map' => File::exists($projectIdMapPath)
                ? json_decode(File::get($projectIdMapPath), true)
                : null,
            'project_id_map_mock' => File::exists($projectIdMapMockPath)
                ? json_decode(File::get($projectIdMapMockPath), true)
                : null,
            'project_id_map_resolved' => File::exists($projectIdMapResolvedPath)
                ? json_decode(File::get($projectIdMapResolvedPath), true)
                : null,
            'unit_user_id_map' => File::exists($unitUserIdMapPath)
                ? json_decode(File::get($unitUserIdMapPath), true)
                : null,
            'unit_user_id_map_mock' => File::exists($unitUserIdMapMockPath)
                ? json_decode(File::get($unitUserIdMapMockPath), true)
                : null,
            'unit_user_id_map_resolved' => File::exists($unitUserIdMapResolvedPath)
                ? json_decode(File::get($unitUserIdMapResolvedPath), true)
                : null,
            'unit_user_db_dry_run' => File::exists($unitUserDbDryRunPath)
                ? json_decode(File::get($unitUserDbDryRunPath), true)
                : null,
            'unit_user_db_dry_run_mock' => File::exists($unitUserDbDryRunMockPath)
                ? json_decode(File::get($unitUserDbDryRunMockPath), true)
                : null,
            'unit_user_db_dry_run_resolved' => File::exists($unitUserDbDryRunResolvedPath)
                ? json_decode(File::get($unitUserDbDryRunResolvedPath), true)
                : null,
            'project_db_dry_run' => File::exists($projectDbDryRunPath)
                ? json_decode(File::get($projectDbDryRunPath), true)
                : null,
            'project_db_dry_run_mock' => File::exists($projectDbDryRunMockPath)
                ? json_decode(File::get($projectDbDryRunMockPath), true)
                : null,
            'project_db_dry_run_resolved' => File::exists($projectDbDryRunResolvedPath)
                ? json_decode(File::get($projectDbDryRunResolvedPath), true)
                : null,
            'project_file_db_dry_run' => File::exists($projectFileDbDryRunPath)
                ? json_decode(File::get($projectFileDbDryRunPath), true)
                : null,
            'project_file_db_dry_run_mock' => File::exists($projectFileDbDryRunMockPath)
                ? json_decode(File::get($projectFileDbDryRunMockPath), true)
                : null,
            'project_file_db_dry_run_resolved' => File::exists($projectFileDbDryRunResolvedPath)
                ? json_decode(File::get($projectFileDbDryRunResolvedPath), true)
                : null,
            'workflow_db_dry_run' => File::exists($workflowDbDryRunPath)
                ? json_decode(File::get($workflowDbDryRunPath), true)
                : null,
            'workflow_db_dry_run_mock' => File::exists($workflowDbDryRunMockPath)
                ? json_decode(File::get($workflowDbDryRunMockPath), true)
                : null,
            'workflow_orphan_resolution_signoff' => File::exists($workflowOrphanResolutionSignoffPath)
                ? json_decode(File::get($workflowOrphanResolutionSignoffPath), true)
                : null,
            'workflow_orphan_resolution_signoff_validation' => File::exists($workflowOrphanResolutionSignoffValidationPath)
                ? json_decode(File::get($workflowOrphanResolutionSignoffValidationPath), true)
                : null,
            'workflow_orphan_operator_pack' => File::exists($workflowOrphanOperatorPackPath)
                ? json_decode(File::get($workflowOrphanOperatorPackPath), true)
                : null,
            'workflow_orphan_operator_pack_validation' => File::exists($workflowOrphanOperatorPackValidationPath)
                ? json_decode(File::get($workflowOrphanOperatorPackValidationPath), true)
                : null,
            'migration_dry_run_comparison' => File::exists($migrationDryRunComparisonPath)
                ? json_decode(File::get($migrationDryRunComparisonPath), true)
                : null,
            'migration_resolution_acceptance_gate' => File::exists($migrationResolutionAcceptanceGatePath)
                ? json_decode(File::get($migrationResolutionAcceptanceGatePath), true)
                : null,
            'migration_resolution_operator_pack' => File::exists($migrationResolutionOperatorPackPath)
                ? json_decode(File::get($migrationResolutionOperatorPackPath), true)
                : null,
            'migration_resolution_operator_pack_validation' => File::exists($migrationResolutionOperatorPackValidationPath)
                ? json_decode(File::get($migrationResolutionOperatorPackValidationPath), true)
                : null,
            'migration_readiness_summary' => File::exists($migrationReadinessSummaryPath)
                ? json_decode(File::get($migrationReadinessSummaryPath), true)
                : null,
            'migration_batch_plan' => File::exists($migrationBatchPlanPath)
                ? json_decode(File::get($migrationBatchPlanPath), true)
                : null,
            'migration_batch_db_dry_run' => File::exists($migrationBatchDbDryRunPath)
                ? json_decode(File::get($migrationBatchDbDryRunPath), true)
                : null,
            'record_import_plan' => File::exists($recordImportPlanPath)
                ? json_decode(File::get($recordImportPlanPath), true)
                : null,
            'migration_blocker_action_sheet' => File::exists($migrationBlockerActionSheetPath)
                ? json_decode(File::get($migrationBlockerActionSheetPath), true)
                : null,
            'migration_blocker_action_sheet_validation' => File::exists($migrationBlockerActionSheetValidationPath)
                ? json_decode(File::get($migrationBlockerActionSheetValidationPath), true)
                : null,
            'migration_blocker_resolution_pack' => File::exists($migrationBlockerResolutionPackPath)
                ? json_decode(File::get($migrationBlockerResolutionPackPath), true)
                : null,
            'migration_blocker_resolution_pack_validation' => File::exists($migrationBlockerResolutionPackValidationPath)
                ? json_decode(File::get($migrationBlockerResolutionPackValidationPath), true)
                : null,
            'migration_blocker_resolution_signoff' => File::exists($migrationBlockerResolutionSignoffPath)
                ? json_decode(File::get($migrationBlockerResolutionSignoffPath), true)
                : null,
            'migration_blocker_resolution_signoff_validation' => File::exists($migrationBlockerResolutionSignoffValidationPath)
                ? json_decode(File::get($migrationBlockerResolutionSignoffValidationPath), true)
                : null,
            'migration_blocker_resolution_operator_pack' => File::exists($migrationBlockerResolutionOperatorPackPath)
                ? json_decode(File::get($migrationBlockerResolutionOperatorPackPath), true)
                : null,
            'migration_blocker_resolution_operator_pack_validation' => File::exists($migrationBlockerResolutionOperatorPackValidationPath)
                ? json_decode(File::get($migrationBlockerResolutionOperatorPackValidationPath), true)
                : null,
            'migration_resolution_templates' => File::exists($migrationResolutionTemplatesPath)
                ? json_decode(File::get($migrationResolutionTemplatesPath), true)
                : null,
            'migration_resolution_validation' => File::exists($migrationResolutionValidationPath)
                ? json_decode(File::get($migrationResolutionValidationPath), true)
                : null,
            'migration_resolution_progress' => File::exists($migrationResolutionProgressPath)
                ? json_decode(File::get($migrationResolutionProgressPath), true)
                : null,
            'migration_resolution_worklist' => File::exists($migrationResolutionWorklistPath)
                ? json_decode(File::get($migrationResolutionWorklistPath), true)
                : null,
            'migration_resolution_row_worklist' => File::exists($migrationResolutionRowWorklistPath)
                ? json_decode(File::get($migrationResolutionRowWorklistPath), true)
                : null,
            'migration_resolution_owner_row_worklists' => File::exists($migrationResolutionOwnerRowWorklistsPath)
                ? json_decode(File::get($migrationResolutionOwnerRowWorklistsPath), true)
                : null,
            'migration_resolution_owner_template_row_worklists' => File::exists($migrationResolutionOwnerTemplateRowWorklistsPath)
                ? json_decode(File::get($migrationResolutionOwnerTemplateRowWorklistsPath), true)
                : null,
            'migration_resolution_distribution_pack' => File::exists($migrationResolutionDistributionPackPath)
                ? json_decode(File::get($migrationResolutionDistributionPackPath), true)
                : null,
            'migration_resolution_distribution_signoff' => File::exists($migrationResolutionDistributionSignoffPath)
                ? json_decode(File::get($migrationResolutionDistributionSignoffPath), true)
                : null,
            'migration_resolution_distribution_signoff_validation' => File::exists($migrationResolutionDistributionSignoffValidationPath)
                ? json_decode(File::get($migrationResolutionDistributionSignoffValidationPath), true)
                : null,
            'migration_resolution_owner_worklists' => File::exists($migrationResolutionOwnerWorklistsPath)
                ? json_decode(File::get($migrationResolutionOwnerWorklistsPath), true)
                : null,
            'migration_resolution_import_preview' => File::exists($migrationResolutionImportPreviewPath)
                ? json_decode(File::get($migrationResolutionImportPreviewPath), true)
                : null,
            'attachment_exceptions_resolved' => File::exists($attachmentExceptionsResolvedPath)
                ? json_decode(File::get($attachmentExceptionsResolvedPath), true)
                : null,
            'migration_artifact_manifest' => File::exists($migrationArtifactManifestPath)
                ? json_decode(File::get($migrationArtifactManifestPath), true)
                : null,
            'migration_artifact_manifest_validation' => File::exists($migrationArtifactManifestValidationPath)
                ? json_decode(File::get($migrationArtifactManifestValidationPath), true)
                : null,
            'migration_preflight_checklist' => File::exists($migrationPreflightChecklistPath)
                ? json_decode(File::get($migrationPreflightChecklistPath), true)
                : null,
            'migration_preflight_checklist_validation' => File::exists($migrationPreflightChecklistValidationPath)
                ? json_decode(File::get($migrationPreflightChecklistValidationPath), true)
                : null,
            'migration_preflight_blocker_operator_pack' => File::exists($migrationPreflightBlockerOperatorPackPath)
                ? json_decode(File::get($migrationPreflightBlockerOperatorPackPath), true)
                : null,
            'migration_preflight_blocker_operator_pack_validation' => File::exists($migrationPreflightBlockerOperatorPackValidationPath)
                ? json_decode(File::get($migrationPreflightBlockerOperatorPackValidationPath), true)
                : null,
            'migration_go_live_gate' => $migrationGoLiveGate,
            'migration_go_live_gate_validation' => File::exists($migrationGoLiveGateValidationPath)
                ? json_decode(File::get($migrationGoLiveGateValidationPath), true)
                : null,
            'migration_go_live_signoff' => File::exists($migrationGoLiveSignoffPath)
                ? json_decode(File::get($migrationGoLiveSignoffPath), true)
                : null,
            'migration_go_live_signoff_validation' => File::exists($migrationGoLiveSignoffValidationPath)
                ? json_decode(File::get($migrationGoLiveSignoffValidationPath), true)
                : null,
            'migration_go_live_signoff_operator_pack' => File::exists($migrationGoLiveSignoffOperatorPackPath)
                ? json_decode(File::get($migrationGoLiveSignoffOperatorPackPath), true)
                : null,
            'migration_go_live_signoff_operator_pack_validation' => File::exists($migrationGoLiveSignoffOperatorPackValidationPath)
                ? json_decode(File::get($migrationGoLiveSignoffOperatorPackValidationPath), true)
                : null,
            'migration_sampling_acceptance_signoff' => File::exists($migrationSamplingAcceptanceSignoffPath)
                ? json_decode(File::get($migrationSamplingAcceptanceSignoffPath), true)
                : null,
            'migration_sampling_acceptance_signoff_validation' => File::exists($migrationSamplingAcceptanceSignoffValidationPath)
                ? json_decode(File::get($migrationSamplingAcceptanceSignoffValidationPath), true)
                : null,
            'migration_sampling_acceptance_operator_pack' => File::exists($migrationSamplingAcceptanceOperatorPackPath)
                ? json_decode(File::get($migrationSamplingAcceptanceOperatorPackPath), true)
                : null,
            'migration_sampling_acceptance_operator_pack_validation' => File::exists($migrationSamplingAcceptanceOperatorPackValidationPath)
                ? json_decode(File::get($migrationSamplingAcceptanceOperatorPackValidationPath), true)
                : null,
            'migration_go_live_evidence_pack' => File::exists($migrationGoLiveEvidencePackPath)
                ? json_decode(File::get($migrationGoLiveEvidencePackPath), true)
                : null,
            'migration_go_live_evidence_pack_validation' => File::exists($migrationGoLiveEvidencePackValidationPath)
                ? json_decode(File::get($migrationGoLiveEvidencePackValidationPath), true)
                : null,
            'migration_go_live_drill_operator_pack' => File::exists($migrationGoLiveDrillOperatorPackPath)
                ? json_decode(File::get($migrationGoLiveDrillOperatorPackPath), true)
                : null,
            'migration_go_live_drill_operator_pack_validation' => File::exists($migrationGoLiveDrillOperatorPackValidationPath)
                ? json_decode(File::get($migrationGoLiveDrillOperatorPackValidationPath), true)
                : null,
            'migration_operational_docs_validation' => File::exists($migrationOperationalDocsValidationPath)
                ? json_decode(File::get($migrationOperationalDocsValidationPath), true)
                : null,
            'legacy_security_baseline_operator_pack' => File::exists($securityBaselineOperatorPackPath)
                ? json_decode(File::get($securityBaselineOperatorPackPath), true)
                : null,
            'legacy_security_baseline_operator_pack_validation' => File::exists($securityBaselineOperatorPackValidationPath)
                ? json_decode(File::get($securityBaselineOperatorPackValidationPath), true)
                : null,
            'legacy_security_baseline_signoff' => File::exists($securityBaselineSignoffPath)
                ? json_decode(File::get($securityBaselineSignoffPath), true)
                : null,
            'legacy_security_baseline_signoff_validation' => File::exists($securityBaselineSignoffValidationPath)
                ? json_decode(File::get($securityBaselineSignoffValidationPath), true)
                : null,
            'legacy_security_public_executable_worklist' => File::exists($securityPublicExecutableWorklistPath)
                ? json_decode(File::get($securityPublicExecutableWorklistPath), true)
                : null,
            'legacy_security_public_executable_worklist_validation' => File::exists($securityPublicExecutableWorklistValidationPath)
                ? json_decode(File::get($securityPublicExecutableWorklistValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_plan' => File::exists($securityPublicExecutableRemediationPlanPath)
                ? json_decode(File::get($securityPublicExecutableRemediationPlanPath), true)
                : null,
            'legacy_security_public_executable_remediation_plan_validation' => File::exists($securityPublicExecutableRemediationPlanValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationPlanValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_files' => File::exists($securityPublicExecutableRemediationWaveFilesPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveFilesPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_files_validation' => File::exists($securityPublicExecutableRemediationWaveFilesValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveFilesValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff' => File::exists($securityPublicExecutableRemediationWaveSignoffPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_validation' => File::exists($securityPublicExecutableRemediationWaveSignoffValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_operator_pack' => File::exists($securityPublicExecutableRemediationWaveSignoffOperatorPackPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffOperatorPackPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation' => File::exists($securityPublicExecutableRemediationWaveSignoffOperatorPackValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffOperatorPackValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_pack' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffPackPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffPackPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffPackValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffPackValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffSignoffPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffSignoffPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffSignoffValidationPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackPath), true)
                : null,
            'legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation' => File::exists($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath)
                ? json_decode(File::get($securityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPackValidationPath), true)
                : null,
            'migration_next_actions' => File::exists($migrationNextActionsPath)
                ? json_decode(File::get($migrationNextActionsPath), true)
                : null,
            'migration_next_actions_validation' => File::exists($migrationNextActionsValidationPath)
                ? json_decode(File::get($migrationNextActionsValidationPath), true)
                : null,
            'migration_next_actions_owner_files_validation' => File::exists($migrationNextActionsOwnerFilesValidationPath)
                ? json_decode(File::get($migrationNextActionsOwnerFilesValidationPath), true)
                : null,
            'migration_next_actions_owner_signoff' => File::exists($migrationNextActionsOwnerSignoffPath)
                ? json_decode(File::get($migrationNextActionsOwnerSignoffPath), true)
                : null,
            'migration_next_actions_owner_signoff_validation' => File::exists($migrationNextActionsOwnerSignoffValidationPath)
                ? json_decode(File::get($migrationNextActionsOwnerSignoffValidationPath), true)
                : null,
            'migration_next_actions_owner_signoff_operator_pack' => File::exists($migrationNextActionsOwnerSignoffOperatorPackPath)
                ? json_decode(File::get($migrationNextActionsOwnerSignoffOperatorPackPath), true)
                : null,
            'migration_next_actions_owner_signoff_operator_pack_validation' => File::exists($migrationNextActionsOwnerSignoffOperatorPackValidationPath)
                ? json_decode(File::get($migrationNextActionsOwnerSignoffOperatorPackValidationPath), true)
                : null,
        ]);
    }
}







