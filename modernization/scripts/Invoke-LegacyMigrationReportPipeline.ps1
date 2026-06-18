param(
    [switch]$WithMock,
    [switch]$SkipAttachmentQuality,
    [switch]$SkipAttachmentIndex,
    [switch]$SkipProjectCore,
    [switch]$SkipProjectFileDb,
    [int]$MockProjectStartId = 100000,
    [int]$MockUnitStartId = 200000,
    [int]$MockUserStartId = 300000,
    [switch]$ForceResolutionTemplates
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )

    Write-Host "==> $Name"
    & $ScriptPath @Parameters
}

$scriptsRoot = $PSScriptRoot

if (-not $SkipAttachmentQuality) {
    Invoke-Step 'Attachment quality report' (Join-Path $scriptsRoot 'New-LegacyAttachmentQualityReport.ps1')
}

Invoke-Step 'Security baseline operator pack initial' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Security baseline operator pack validation initial' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Security baseline signoff' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline signoff validation' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline operator pack signoff' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Security baseline operator pack validation signoff' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineOperatorPack.ps1')

if (-not $SkipAttachmentIndex) {
    Invoke-Step 'Attachment import index' (Join-Path $scriptsRoot 'New-LegacyAttachmentImportIndex.ps1')
    Invoke-Step 'Attachment import dry-run' (Join-Path $scriptsRoot 'Invoke-LegacyAttachmentImportDryRun.ps1')
    Invoke-Step 'Attachment exception confirmation' (Join-Path $scriptsRoot 'New-LegacyAttachmentExceptionConfirmation.ps1')
    Invoke-Step 'Attachment exception worksheet' (Join-Path $scriptsRoot 'New-LegacyAttachmentExceptionWorksheet.ps1')
    Invoke-Step 'Attachment exception worksheet import preview' (Join-Path $scriptsRoot 'New-LegacyAttachmentExceptionWorksheetImportPreview.ps1')
    Invoke-Step 'Attachment exception template patch preview' (Join-Path $scriptsRoot 'New-LegacyAttachmentExceptionTemplatePatchPreview.ps1')
    Invoke-Step 'Attachment exception operator pack' (Join-Path $scriptsRoot 'New-LegacyAttachmentExceptionOperatorPack.ps1')
    Invoke-Step 'Attachment exception operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyAttachmentExceptionOperatorPack.ps1')
}

if (-not $SkipProjectCore) {
    Invoke-Step 'Unit/user DB dry-run' (Join-Path $scriptsRoot 'New-LegacyUnitUserDbDryRun.ps1')
    Invoke-Step 'Project DB dry-run' (Join-Path $scriptsRoot 'New-LegacyProjectDbDryRun.ps1')
    Invoke-Step 'Unit/user id map' (Join-Path $scriptsRoot 'New-LegacyUnitUserIdMap.ps1')
    Invoke-Step 'Project id map' (Join-Path $scriptsRoot 'New-LegacyProjectIdMap.ps1')
}

if ($WithMock) {
    Invoke-Step 'Mock project id map' (Join-Path $scriptsRoot 'New-LegacyProjectIdMap.ps1') -Parameters @{
        Mock = $true
        MockStartId = $MockProjectStartId
        ReportPath = (Join-Path $scriptsRoot 'legacy-project-id-map.mock.json')
    }
    Invoke-Step 'Mock unit/user id map' (Join-Path $scriptsRoot 'New-LegacyUnitUserIdMap.ps1') -Parameters @{
        Mock = $true
        MockUnitStartId = $MockUnitStartId
        MockUserStartId = $MockUserStartId
        ReportPath = (Join-Path $scriptsRoot 'legacy-unit-user-id-map.mock.json')
    }
    Invoke-Step 'Mock unit/user DB dry-run' (Join-Path $scriptsRoot 'New-LegacyUnitUserDbDryRun.ps1') -Parameters @{
        UnitUserMapPath = (Join-Path $scriptsRoot 'legacy-unit-user-id-map.mock.json')
        ReportPath = (Join-Path $scriptsRoot 'legacy-unit-user-db-dry-run.mock.json')
    }
    Invoke-Step 'Mock project DB dry-run' (Join-Path $scriptsRoot 'New-LegacyProjectDbDryRun.ps1') -Parameters @{
        UnitUserMapPath = (Join-Path $scriptsRoot 'legacy-unit-user-id-map.mock.json')
        ReportPath = (Join-Path $scriptsRoot 'legacy-project-db-dry-run.mock.json')
    }
}

if (-not $SkipProjectFileDb) {
    Invoke-Step 'Project file DB dry-run' (Join-Path $scriptsRoot 'New-LegacyProjectFileDbDryRun.ps1')
    Invoke-Step 'Workflow DB dry-run' (Join-Path $scriptsRoot 'New-LegacyWorkflowDbDryRun.ps1')
    if ($WithMock) {
        Invoke-Step 'Mock project file DB dry-run' (Join-Path $scriptsRoot 'New-LegacyProjectFileDbDryRun.ps1') -Parameters @{
            ProjectIdMapPath = (Join-Path $scriptsRoot 'legacy-project-id-map.mock.json')
            ReportPath = (Join-Path $scriptsRoot 'legacy-project-file-db-dry-run.mock.json')
        }
        Invoke-Step 'Mock workflow DB dry-run' (Join-Path $scriptsRoot 'New-LegacyWorkflowDbDryRun.ps1') -Parameters @{
            ProjectIdMapPath = (Join-Path $scriptsRoot 'legacy-project-id-map.mock.json')
            ReportPath = (Join-Path $scriptsRoot 'legacy-workflow-db-dry-run.mock.json')
        }
    }
}

Invoke-Step 'Migration readiness summary' (Join-Path $scriptsRoot 'New-LegacyMigrationReadinessSummary.ps1')
Invoke-Step 'Migration batch plan' (Join-Path $scriptsRoot 'New-LegacyMigrationBatchPlan.ps1')
Invoke-Step 'Migration batch DB dry-run' (Join-Path $scriptsRoot 'New-LegacyMigrationBatchDbDryRun.ps1')
Invoke-Step 'Legacy record import plan' (Join-Path $scriptsRoot 'New-LegacyRecordImportPlan.ps1')
Invoke-Step 'Migration blocker action sheet' (Join-Path $scriptsRoot 'New-LegacyMigrationBlockerActionSheet.ps1')
Invoke-Step 'Migration blocker action sheet validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationBlockerActionSheet.ps1')
Invoke-Step 'Migration blocker resolution pack' (Join-Path $scriptsRoot 'New-LegacyMigrationBlockerResolutionPack.ps1')
Invoke-Step 'Migration blocker resolution pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationBlockerResolutionPack.ps1')
Invoke-Step 'Migration blocker resolution signoff' (Join-Path $scriptsRoot 'New-LegacyMigrationBlockerResolutionSignoff.ps1')
Invoke-Step 'Migration blocker resolution signoff validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationBlockerResolutionSignoff.ps1')
Invoke-Step 'Migration blocker resolution operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationBlockerResolutionOperatorPack.ps1')
Invoke-Step 'Migration blocker resolution operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationBlockerResolutionOperatorPack.ps1')
Invoke-Step 'Migration resolution templates' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionTemplates.ps1') -Parameters @{ Force = $ForceResolutionTemplates }
Invoke-Step 'Migration resolution validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationResolutionTemplates.ps1')
Invoke-Step 'Migration resolution progress' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionProgress.ps1')
Invoke-Step 'Migration resolution worklist' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionWorklist.ps1')
Invoke-Step 'Migration resolution worklist CSV' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionWorklistCsv.ps1')
Invoke-Step 'Migration resolution row worklist' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionRowWorklist.ps1')
Invoke-Step 'Migration resolution owner row worklists' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionOwnerRowWorklists.ps1')
Invoke-Step 'Migration resolution owner template row worklists' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionOwnerTemplateRowWorklists.ps1')
Invoke-Step 'Migration resolution distribution pack' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionDistributionPack.ps1')
Invoke-Step 'Migration resolution distribution signoff' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionDistributionSignoff.ps1')
Invoke-Step 'Migration resolution distribution signoff validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationResolutionDistributionSignoff.ps1')
Invoke-Step 'Migration resolution owner worklists' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionOwnerWorklists.ps1')
Invoke-Step 'Migration resolution import preview' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionImportPreview.ps1')
Invoke-Step 'Resolved mapping reports' (Join-Path $scriptsRoot 'New-LegacyResolvedMappingReports.ps1')
Invoke-Step 'Resolved mapping DB dry-run' (Join-Path $scriptsRoot 'Invoke-LegacyResolvedMappingDryRun.ps1')
Invoke-Step 'Migration dry-run comparison' (Join-Path $scriptsRoot 'New-LegacyMigrationDryRunComparison.ps1')
Invoke-Step 'Workflow orphan resolution signoff' (Join-Path $scriptsRoot 'New-LegacyWorkflowOrphanResolutionSignoff.ps1')
Invoke-Step 'Workflow orphan resolution signoff validation' (Join-Path $scriptsRoot 'Test-LegacyWorkflowOrphanResolutionSignoff.ps1')
Invoke-Step 'Workflow orphan operator pack' (Join-Path $scriptsRoot 'New-LegacyWorkflowOrphanOperatorPack.ps1')
Invoke-Step 'Workflow orphan operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyWorkflowOrphanOperatorPack.ps1')
Invoke-Step 'Migration resolution acceptance gate' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionAcceptanceGate.ps1')
Invoke-Step 'Migration resolution operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationResolutionOperatorPack.ps1')
Invoke-Step 'Migration resolution operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationResolutionOperatorPack.ps1')
Invoke-Step 'Migration go-live drill report' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveDrillReport.ps1')
Invoke-Step 'Migration rollback plan' (Join-Path $scriptsRoot 'New-LegacyMigrationRollbackPlan.ps1')
Invoke-Step 'Migration operator runbook' (Join-Path $scriptsRoot 'New-LegacyMigrationOperatorRunbook.ps1')
Invoke-Step 'Migration operational docs validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationOperationalDocs.ps1')
Invoke-Step 'Migration sampling acceptance signoff' (Join-Path $scriptsRoot 'New-LegacyMigrationSamplingAcceptanceSignoff.ps1')
Invoke-Step 'Migration sampling acceptance signoff validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationSamplingAcceptanceSignoff.ps1')
Invoke-Step 'Migration sampling acceptance operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationSamplingAcceptanceOperatorPack.ps1')
Invoke-Step 'Migration sampling acceptance operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationSamplingAcceptanceOperatorPack.ps1')
Invoke-Step 'Migration go-live signoff' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveSignoff.ps1')
Invoke-Step 'Migration go-live signoff validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveSignoff.ps1')
Invoke-Step 'Migration go-live signoff operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveSignoffOperatorPack.ps1')
Invoke-Step 'Migration go-live signoff operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveSignoffOperatorPack.ps1')
Invoke-Step 'Migration go-live gate' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveGate.ps1')
Invoke-Step 'Migration go-live gate validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveGate.ps1')
Invoke-Step 'Security baseline signoff preflight' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline signoff validation preflight' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline operator pack preflight' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Security baseline operator pack validation preflight' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Migration go-live evidence pack preflight' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live evidence pack validation preflight' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live drill operator pack preflight' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveDrillOperatorPack.ps1')
Invoke-Step 'Migration go-live drill operator pack validation preflight' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveDrillOperatorPack.ps1')
Invoke-Step 'Migration artifact manifest' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest after validation' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration preflight checklist' (Join-Path $scriptsRoot 'New-LegacyMigrationPreflightChecklist.ps1')
Invoke-Step 'Migration preflight checklist validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationPreflightChecklist.ps1')
Invoke-Step 'Preflight blocker operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationPreflightBlockerOperatorPack.ps1')
Invoke-Step 'Preflight blocker operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationPreflightBlockerOperatorPack.ps1')
Invoke-Step 'Migration go-live gate final' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveGate.ps1')
Invoke-Step 'Migration go-live gate validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveGate.ps1')
Invoke-Step 'Security baseline signoff final' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline signoff validation final' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineSignoff.ps1')
Invoke-Step 'Security baseline operator pack final' (Join-Path $scriptsRoot 'New-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Security baseline operator pack validation final' (Join-Path $scriptsRoot 'Test-LegacySecurityBaselineOperatorPack.ps1')
Invoke-Step 'Migration go-live evidence pack' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live evidence pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live drill operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveDrillOperatorPack.ps1')
Invoke-Step 'Migration go-live drill operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveDrillOperatorPack.ps1')
Invoke-Step 'Migration next actions report' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsReport.ps1')
Invoke-Step 'Migration next actions validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActions.ps1')
Invoke-Step 'Migration next actions owner files validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerFiles.ps1')
Invoke-Step 'Migration next actions owner signoff' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsOwnerSignoff.ps1')
Invoke-Step 'Migration next actions owner signoff validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerSignoff.ps1')
Invoke-Step 'Migration next actions owner signoff operator pack' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1')
Invoke-Step 'Migration next actions owner signoff operator pack validation' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1')
Invoke-Step 'Preflight blocker operator pack final' (Join-Path $scriptsRoot 'New-LegacyMigrationPreflightBlockerOperatorPack.ps1')
Invoke-Step 'Preflight blocker operator pack validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationPreflightBlockerOperatorPack.ps1')
Invoke-Step 'Migration go-live evidence pack final' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live evidence pack validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration artifact manifest final' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation final pass' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest final after validation' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation final closing' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration next actions report final' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsReport.ps1')
Invoke-Step 'Migration next actions validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActions.ps1')
Invoke-Step 'Migration next actions owner files validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerFiles.ps1')
Invoke-Step 'Migration next actions owner signoff final' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsOwnerSignoff.ps1')
Invoke-Step 'Migration next actions owner signoff validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerSignoff.ps1')
Invoke-Step 'Migration next actions owner signoff operator pack final' (Join-Path $scriptsRoot 'New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1')
Invoke-Step 'Migration next actions owner signoff operator pack validation final' (Join-Path $scriptsRoot 'Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1')
Invoke-Step 'Migration go-live evidence pack closing' (Join-Path $scriptsRoot 'New-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration go-live evidence pack validation closing' (Join-Path $scriptsRoot 'Test-LegacyMigrationGoLiveEvidencePack.ps1')
Invoke-Step 'Migration artifact manifest closing' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation closing' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest closing after validation' (Join-Path $scriptsRoot 'New-LegacyMigrationArtifactManifest.ps1')
Invoke-Step 'Migration artifact manifest validation closed' (Join-Path $scriptsRoot 'Test-LegacyMigrationArtifactManifest.ps1')

Write-Host 'Legacy migration report pipeline completed.'




