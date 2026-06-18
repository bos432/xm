param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-artifact-manifest-validation.json"),
    [string]$ManifestPath = (Join-Path $PSScriptRoot "legacy-migration-artifact-manifest.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        field = $field
        code = $code
        message = $message
    })
}

$manifest = Read-JsonReport $ManifestPath
$issues = New-Object System.Collections.Generic.List[object]
$artifactCount = 0
$requiredCount = 0
$existingCount = 0
$missingRequiredCount = 0
$missingOptionalCount = 0
$duplicateKeyCount = 0
$unknownDependencyCount = 0
$existenceMismatches = 0
$missingRequiredListMismatches = 0
$missingOptionalListMismatches = 0

if (-not $manifest) {
    Add-Issue $issues 'blocker' $ManifestPath 'missing_manifest' 'artifact manifest is missing.'
} else {
    $artifacts = @($manifest.artifacts)
    $artifactCount = $artifacts.Count
    $requiredArtifacts = @($artifacts | Where-Object { $_.required })
    $existingArtifacts = @($artifacts | Where-Object { $_.exists })
    $missingRequired = @($requiredArtifacts | Where-Object { -not $_.exists })
    $missingOptional = @($artifacts | Where-Object { -not $_.required -and -not $_.exists })
    $requiredCount = $requiredArtifacts.Count
    $existingCount = $existingArtifacts.Count
    $missingRequiredCount = $missingRequired.Count
    $missingOptionalCount = $missingOptional.Count

    if ($manifest.summary.total_artifacts -ne $artifactCount) {
        Add-Issue $issues 'blocker' 'summary.total_artifacts' 'summary_count_mismatch' "summary total_artifacts ($($manifest.summary.total_artifacts)) does not match artifacts count ($artifactCount)."
    }
    if ($manifest.summary.required_artifacts -ne $requiredCount) {
        Add-Issue $issues 'blocker' 'summary.required_artifacts' 'summary_count_mismatch' "summary required_artifacts ($($manifest.summary.required_artifacts)) does not match required artifact count ($requiredCount)."
    }
    if ($manifest.summary.existing_artifacts -ne $existingCount) {
        Add-Issue $issues 'blocker' 'summary.existing_artifacts' 'summary_count_mismatch' "summary existing_artifacts ($($manifest.summary.existing_artifacts)) does not match existing artifact count ($existingCount)."
    }
    if ($manifest.summary.missing_required -ne $missingRequiredCount) {
        Add-Issue $issues 'blocker' 'summary.missing_required' 'summary_count_mismatch' "summary missing_required ($($manifest.summary.missing_required)) does not match missing required artifact count ($missingRequiredCount)."
    }
    if ($manifest.summary.missing_optional -ne $missingOptionalCount) {
        Add-Issue $issues 'warning' 'summary.missing_optional' 'summary_count_mismatch' "summary missing_optional ($($manifest.summary.missing_optional)) does not match missing optional artifact count ($missingOptionalCount)."
    }

    $manifestMissingRequired = @($manifest.missing_required | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
    $calculatedMissingRequired = @($missingRequired | ForEach-Object { $_.key } | Sort-Object -Unique)
    $requiredOnlyInManifest = @($manifestMissingRequired | Where-Object { $calculatedMissingRequired -notcontains $_ })
    $requiredOnlyCalculated = @($calculatedMissingRequired | Where-Object { $manifestMissingRequired -notcontains $_ })
    $missingRequiredListMismatches = $requiredOnlyInManifest.Count + $requiredOnlyCalculated.Count
    foreach ($key in $requiredOnlyInManifest) {
        Add-Issue $issues 'blocker' 'missing_required' 'missing_required_list_mismatch' "missing_required includes $key but the artifact is not currently missing."
    }
    foreach ($key in $requiredOnlyCalculated) {
        Add-Issue $issues 'blocker' 'missing_required' 'missing_required_list_mismatch' "required artifact $key is missing but is not listed in missing_required."
    }

    $manifestMissingOptional = @($manifest.missing_optional | Where-Object { -not (Test-Blank $_) } | Sort-Object -Unique)
    $calculatedMissingOptional = @($missingOptional | ForEach-Object { $_.key } | Sort-Object -Unique)
    $optionalOnlyInManifest = @($manifestMissingOptional | Where-Object { $calculatedMissingOptional -notcontains $_ })
    $optionalOnlyCalculated = @($calculatedMissingOptional | Where-Object { $manifestMissingOptional -notcontains $_ })
    $missingOptionalListMismatches = $optionalOnlyInManifest.Count + $optionalOnlyCalculated.Count
    foreach ($key in $optionalOnlyInManifest) {
        Add-Issue $issues 'warning' 'missing_optional' 'missing_optional_list_mismatch' "missing_optional includes $key but the artifact is not currently missing."
    }
    foreach ($key in $optionalOnlyCalculated) {
        Add-Issue $issues 'warning' 'missing_optional' 'missing_optional_list_mismatch' "optional artifact $key is missing but is not listed in missing_optional."
    }

    $keys = @($artifacts | ForEach-Object { $_.key })
    foreach ($group in @($keys | Group-Object | Where-Object { $_.Count -gt 1 })) {
        $duplicateKeyCount++
        Add-Issue $issues 'blocker' 'artifacts.key' 'duplicate_artifact_key' "artifact key is duplicated: $($group.Name)."
    }

    foreach ($artifact in $artifacts) {
        if (Test-Blank $artifact.key) {
            Add-Issue $issues 'blocker' 'artifacts.key' 'blank_artifact_key' 'artifact has a blank key.'
        }
        if (Test-Blank $artifact.path) {
            Add-Issue $issues 'blocker' "artifacts.$($artifact.key).path" 'blank_artifact_path' "artifact $($artifact.key) has a blank path."
        } else {
            $diskExists = Test-Path -LiteralPath $artifact.path
            if ([bool]$artifact.exists -ne [bool]$diskExists) {
                $existenceMismatches++
                Add-Issue $issues 'blocker' "artifacts.$($artifact.key).exists" 'artifact_exists_mismatch' "artifact $($artifact.key) exists flag ($($artifact.exists)) does not match disk existence ($diskExists)."
            }
        }

        foreach ($dependency in @($artifact.depends_on)) {
            if (Test-Blank $dependency) { continue }
            if ($keys -notcontains $dependency) {
                $unknownDependencyCount++
                Add-Issue $issues 'warning' "artifacts.$($artifact.key).depends_on" 'unknown_dependency' "artifact $($artifact.key) depends on unknown artifact key $dependency."
            }
        }
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates artifact manifest structure, summary counts, dependency references, and file existence flags. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if (-not $manifest) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        artifacts = $artifactCount
        required_artifacts = $requiredCount
        existing_artifacts = $existingCount
        missing_required = $missingRequiredCount
        missing_optional = $missingOptionalCount
        duplicate_keys = $duplicateKeyCount
        unknown_dependencies = $unknownDependencyCount
        existence_mismatches = $existenceMismatches
        missing_required_list_mismatches = $missingRequiredListMismatches
        missing_optional_list_mismatches = $missingOptionalListMismatches
        blockers = $blockers
        warnings = $warnings
    }
    manifest = $ManifestPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration artifact manifest validation written to $ReportPath"
