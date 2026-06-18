param(
    [string]$ScriptsRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [string]$Name,
        [string]$ScriptName,
        [switch]$WithoutScriptsRoot
    )

    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    Write-Host "==> $Name"
    if ($WithoutScriptsRoot) {
        & $scriptPath
        return
    }

    & $scriptPath -ScriptsRoot $ScriptsRoot
}

# The go-live reports have a few intentional cross-links: preflight summarizes
# security and drill packs, while drill also summarizes preflight. Run a seed
# pass followed by a convergence pass so one refresh reflects current inputs.
Invoke-Step 'Security public executable worklist' 'New-LegacySecurityPublicExecutableWorklist.ps1'
Invoke-Step 'Security public executable worklist validation' 'Test-LegacySecurityPublicExecutableWorklist.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation plan' 'New-LegacySecurityPublicExecutableRemediationPlan.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation plan validation' 'Test-LegacySecurityPublicExecutableRemediationPlan.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave files' 'New-LegacySecurityPublicExecutableRemediationWaveFiles.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave files validation' 'Test-LegacySecurityPublicExecutableRemediationWaveFiles.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff' 'New-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff validation' 'Test-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff operator pack' 'New-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff operator pack validation' 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff pack' 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff pack validation' 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff signoff' 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff signoff validation' 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff signoff operator pack' 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Security public executable remediation wave signoff handoff signoff operator pack validation' 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Attachment exception operator pack validation' 'Test-LegacyAttachmentExceptionOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration blocker action sheet validation' 'Test-LegacyMigrationBlockerActionSheet.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration blocker resolution operator pack validation' 'Test-LegacyMigrationBlockerResolutionOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration resolution operator pack validation' 'Test-LegacyMigrationResolutionOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live signoff operator pack validation' 'Test-LegacyMigrationGoLiveSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration sampling acceptance operator pack validation' 'Test-LegacyMigrationSamplingAcceptanceOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Workflow orphan operator pack validation' 'Test-LegacyWorkflowOrphanOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest baseline' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation baseline' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest baseline after validation' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation baseline final' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot

Invoke-Step 'Security baseline operator pack seed' 'New-LegacySecurityBaselineOperatorPack.ps1'
Invoke-Step 'Security baseline operator pack validation seed' 'Test-LegacySecurityBaselineOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after security baseline validation seed' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation after security baseline seed' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after manifest validation seed' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration preflight checklist seed' 'New-LegacyMigrationPreflightChecklist.ps1'
Invoke-Step 'Migration preflight checklist validation seed' 'Test-LegacyMigrationPreflightChecklist.ps1' -WithoutScriptsRoot
Invoke-Step 'Preflight blocker operator pack seed' 'New-LegacyMigrationPreflightBlockerOperatorPack.ps1'
Invoke-Step 'Preflight blocker operator pack validation seed' 'Test-LegacyMigrationPreflightBlockerOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live gate seed' 'New-LegacyMigrationGoLiveGate.ps1'
Invoke-Step 'Migration go-live gate validation seed' 'Test-LegacyMigrationGoLiveGate.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live evidence pack seed' 'New-LegacyMigrationGoLiveEvidencePack.ps1'
Invoke-Step 'Migration go-live evidence pack validation seed' 'Test-LegacyMigrationGoLiveEvidencePack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live drill operator pack seed' 'New-LegacyMigrationGoLiveDrillOperatorPack.ps1'
Invoke-Step 'Migration go-live drill operator pack validation seed' 'Test-LegacyMigrationGoLiveDrillOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after drill validation seed' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation after drill seed' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after manifest validation seed final' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions report seed' 'New-LegacyMigrationNextActionsReport.ps1'
Invoke-Step 'Migration next actions validation seed' 'Test-LegacyMigrationNextActions.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner files validation seed' 'Test-LegacyMigrationNextActionsOwnerFiles.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff seed' 'New-LegacyMigrationNextActionsOwnerSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff validation seed' 'Test-LegacyMigrationNextActionsOwnerSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff operator pack seed' 'New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff operator pack validation seed' 'Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' -WithoutScriptsRoot

Invoke-Step 'Security baseline operator pack final' 'New-LegacySecurityBaselineOperatorPack.ps1'
Invoke-Step 'Security baseline operator pack validation final' 'Test-LegacySecurityBaselineOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after security baseline validation final' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation after security baseline final' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after manifest validation final seed' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration preflight checklist final' 'New-LegacyMigrationPreflightChecklist.ps1'
Invoke-Step 'Migration preflight checklist validation final' 'Test-LegacyMigrationPreflightChecklist.ps1' -WithoutScriptsRoot
Invoke-Step 'Preflight blocker operator pack final' 'New-LegacyMigrationPreflightBlockerOperatorPack.ps1'
Invoke-Step 'Preflight blocker operator pack validation final' 'Test-LegacyMigrationPreflightBlockerOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration operational docs validation final' 'Test-LegacyMigrationOperationalDocs.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live gate final' 'New-LegacyMigrationGoLiveGate.ps1'
Invoke-Step 'Migration go-live gate validation final' 'Test-LegacyMigrationGoLiveGate.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live evidence pack final' 'New-LegacyMigrationGoLiveEvidencePack.ps1'
Invoke-Step 'Migration go-live evidence pack validation final' 'Test-LegacyMigrationGoLiveEvidencePack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live drill operator pack final' 'New-LegacyMigrationGoLiveDrillOperatorPack.ps1'
Invoke-Step 'Migration go-live drill operator pack validation final' 'Test-LegacyMigrationGoLiveDrillOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after drill validation final' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation after drill final' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after manifest validation final' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions report final' 'New-LegacyMigrationNextActionsReport.ps1'
Invoke-Step 'Migration next actions validation final' 'Test-LegacyMigrationNextActions.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner files validation final' 'Test-LegacyMigrationNextActionsOwnerFiles.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff final' 'New-LegacyMigrationNextActionsOwnerSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff validation final' 'Test-LegacyMigrationNextActionsOwnerSignoff.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff operator pack final' 'New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration next actions owner signoff operator pack validation final' 'Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration go-live evidence pack with final next actions' 'New-LegacyMigrationGoLiveEvidencePack.ps1'
Invoke-Step 'Migration go-live evidence pack validation with final next actions' 'Test-LegacyMigrationGoLiveEvidencePack.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest after drill validation' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation after final evidence' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest final' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation final' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest final after validation' 'New-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot
Invoke-Step 'Migration artifact manifest validation closing' 'Test-LegacyMigrationArtifactManifest.ps1' -WithoutScriptsRoot

Write-Host 'Legacy go-live readiness reports refreshed.'
