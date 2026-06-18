param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-blocker-operator-pack-validation.json"),
    [string]$OperatorPackPath = (Join-Path $PSScriptRoot "legacy-migration-preflight-blocker-operator-pack.json")
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

$operatorPack = Read-JsonReport $OperatorPackPath
$issues = New-Object System.Collections.Generic.List[object]
$validStatuses = @('ready', 'not_ready', 'blocked', 'missing', 'open', 'warning', 'done')
$validSeverities = @('blocker', 'warning', 'info')

if (-not $operatorPack) {
    Add-Issue $issues 'blocker' 'operator_pack' 'missing_operator_pack' 'preflight blocker operator pack report is missing.'
} else {
    $actions = @($operatorPack.actions)
    $owners = @($operatorPack.owners)
    $topActions = @($operatorPack.top_actions)
    $files = @($operatorPack.files)
    $summary = $operatorPack.summary

    if (Test-Blank $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'blank_overall_status' 'operator pack overall_status is blank.'
    } elseif ($validStatuses -notcontains $operatorPack.overall_status) {
        Add-Issue $issues 'blocker' 'overall_status' 'invalid_overall_status' "operator pack overall_status is invalid: $($operatorPack.overall_status)."
    }

    if ($actions.Count -eq 0) {
        Add-Issue $issues 'blocker' 'actions' 'missing_actions' 'operator pack has no actions.'
    }

    if ($topActions.Count -gt 15) {
        Add-Issue $issues 'blocker' 'top_actions' 'too_many_top_actions' "operator pack top_actions should contain at most 15 rows, found $($topActions.Count)."
    }

    if ($files.Count -ne 9) {
        Add-Issue $issues 'blocker' 'files' 'file_count_mismatch' "operator pack should contain 9 file entries, found $($files.Count)."
    }

    foreach ($action in $actions) {
        if (Test-Blank $action.category) { Add-Issue $issues 'warning' 'actions.category' 'blank_action_category' "action $($action.order) category is blank." }
        if (Test-Blank $action.title) { Add-Issue $issues 'warning' 'actions.title' 'blank_action_title' "action $($action.order) title is blank." }
        if (Test-Blank $action.owner) { Add-Issue $issues 'warning' 'actions.owner' 'blank_action_owner' "action $($action.order) owner is blank." }
        if (Test-Blank $action.action) { Add-Issue $issues 'warning' 'actions.action' 'blank_action_action' "action $($action.order) action is blank." }
        if (Test-Blank $action.acceptance) { Add-Issue $issues 'warning' 'actions.acceptance' 'blank_action_acceptance' "action $($action.order) acceptance is blank." }
        if ($validSeverities -notcontains $action.severity) {
            Add-Issue $issues 'blocker' 'actions.severity' 'invalid_action_severity' "action $($action.order) has invalid severity: $($action.severity)."
        }
        if ($validStatuses -notcontains $action.status) {
            Add-Issue $issues 'blocker' 'actions.status' 'invalid_action_status' "action $($action.order) has invalid status: $($action.status)."
        }
    }

    foreach ($file in $files) {
        if (Test-Blank $file.key) { Add-Issue $issues 'warning' 'files.key' 'blank_file_key' 'operator file entry key is blank.' }
        if (Test-Blank $file.path) {
            Add-Issue $issues 'blocker' 'files.path' 'blank_file_path' "operator file $($file.key) path is blank."
        } elseif ($file.required -and -not (Test-Path -LiteralPath $file.path -PathType Leaf)) {
            Add-Issue $issues 'blocker' 'files.path' 'missing_required_file' "required operator file $($file.key) is missing: $($file.path)."
        }
    }

    $blockerCount = @($actions | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($actions | Where-Object { $_.severity -eq 'warning' }).Count
    $ownerCount = @($actions | Select-Object -ExpandProperty owner -Unique).Count
    if ([int]$summary.total_actions -ne $actions.Count) { Add-Issue $issues 'blocker' 'summary.total_actions' 'total_action_count_mismatch' 'summary total_actions does not match actions count.' }
    if ([int]$summary.blockers -ne $blockerCount) { Add-Issue $issues 'blocker' 'summary.blockers' 'blocker_count_mismatch' 'summary blockers does not match action severities.' }
    if ([int]$summary.warnings -ne $warningCount) { Add-Issue $issues 'blocker' 'summary.warnings' 'warning_count_mismatch' 'summary warnings does not match action severities.' }
    if ([int]$summary.owner_count -ne $ownerCount) { Add-Issue $issues 'blocker' 'summary.owner_count' 'owner_count_mismatch' 'summary owner_count does not match unique action owners.' }
    if ($owners.Count -ne $ownerCount) { Add-Issue $issues 'blocker' 'owners' 'owner_group_count_mismatch' 'owners list count does not match unique action owners.' }

    $expectedStatus = if ($blockerCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'not_ready' } else { 'ready' }
    if ($operatorPack.overall_status -ne $expectedStatus) {
        Add-Issue $issues 'blocker' 'overall_status' 'overall_status_mismatch' "operator pack overall_status should be $expectedStatus based on action severities."
    }

    $firstAction = @($actions | Sort-Object priority, category, title | Select-Object -First 1)
    if ($firstAction.Count -gt 0) {
        if (-not $operatorPack.next_action -or $operatorPack.next_action.title -ne $firstAction[0].title) {
            Add-Issue $issues 'blocker' 'next_action' 'next_action_mismatch' 'operator pack next_action does not match the first sorted action.'
        }
    } elseif ($operatorPack.next_action) {
        Add-Issue $issues 'warning' 'next_action' 'unexpected_next_action' 'operator pack has a next_action even though no actions are present.'
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the preflight blocker operator pack structure and internal counts. It does not copy files, import records, switch traffic, update templates, delete files, quarantine files, or change web server config.'
    overall_status = if (-not $operatorPack) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        actions = if ($operatorPack) { @($operatorPack.actions).Count } else { 0 }
        owners = if ($operatorPack) { @($operatorPack.owners).Count } else { 0 }
        files = if ($operatorPack) { @($operatorPack.files).Count } else { 0 }
        blockers = $blockers
        warnings = $warnings
    }
    operator_pack = $OperatorPackPath
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration preflight blocker operator pack validation written to $ReportPath"
