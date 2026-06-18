param(
    [string]$ScriptsRoot = $PSScriptRoot
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

$unitUserResolvedMapPath = Join-Path $ScriptsRoot 'legacy-unit-user-id-map.resolved.json'
$projectResolvedMapPath = Join-Path $ScriptsRoot 'legacy-project-id-map.resolved.json'

Invoke-Step 'Resolved unit/user DB dry-run' (Join-Path $ScriptsRoot 'New-LegacyUnitUserDbDryRun.ps1') -Parameters @{
    UnitUserMapPath = $unitUserResolvedMapPath
    ReportPath = (Join-Path $ScriptsRoot 'legacy-unit-user-db-dry-run.resolved.json')
}

Invoke-Step 'Resolved project DB dry-run' (Join-Path $ScriptsRoot 'New-LegacyProjectDbDryRun.ps1') -Parameters @{
    UnitUserMapPath = $unitUserResolvedMapPath
    ReportPath = (Join-Path $ScriptsRoot 'legacy-project-db-dry-run.resolved.json')
}

Invoke-Step 'Resolved project file DB dry-run' (Join-Path $ScriptsRoot 'New-LegacyProjectFileDbDryRun.ps1') -Parameters @{
    ProjectIdMapPath = $projectResolvedMapPath
    ReportPath = (Join-Path $ScriptsRoot 'legacy-project-file-db-dry-run.resolved.json')
}

Write-Host 'Resolved mapping dry-run reports completed.'
