param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan-validation.json"),
    [string]$PlanPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.json"),
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-worklist.json"),
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-security-public-executable-remediation-plan.csv")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-CsvRows($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $path -Encoding UTF8)
}

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Get-Wave($category) {
    switch ($category) {
        'uploaded_payload' { return 1 }
        'double_extension_payload' { return 1 }
        'editor_or_demo_handler' { return 2 }
        'static_path_script' { return 3 }
        'cross_language_sample' { return 3 }
        'legacy_public_admin' { return 4 }
        default { return 5 }
    }
}

function Add-Issue($issues, $severity, $code, $itemId, $wave, $field, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        code = $code
        item_id = $itemId
        wave = $wave
        field = $field
        message = $message
    })
}

$plan = Read-JsonReport $PlanPath
$worklist = Read-JsonReport $WorklistPath
$csvRows = Read-CsvRows $CsvPath
$issues = New-Object System.Collections.Generic.List[object]

if (-not $plan) {
    Add-Issue $issues 'blocker' 'missing_plan' '' '' $PlanPath 'remediation plan report is missing.'
}
if (-not $worklist) {
    Add-Issue $issues 'blocker' 'missing_worklist' '' '' $WorklistPath 'public executable worklist report is missing.'
}
if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
    Add-Issue $issues 'blocker' 'missing_csv' '' '' $CsvPath 'remediation plan CSV is missing.'
}

$planItems = if ($plan) { @($plan.items) } else { @() }
$worklistItems = if ($worklist) { @($worklist.items) } else { @() }
$waves = if ($plan) { @($plan.waves) } else { @() }

if ($plan -and $plan.summary.total_files -ne $planItems.Count) {
    Add-Issue $issues 'blocker' 'plan_total_mismatch' '' '' 'summary.total_files' "summary total_files ($($plan.summary.total_files)) does not match plan item count ($($planItems.Count))."
}

if ($worklist -and $planItems.Count -ne $worklistItems.Count) {
    Add-Issue $issues 'blocker' 'worklist_plan_count_mismatch' '' '' 'items' "plan item count ($($planItems.Count)) does not match worklist item count ($($worklistItems.Count))."
}

if ((Test-Path -LiteralPath $CsvPath -PathType Leaf) -and $csvRows.Count -ne $planItems.Count) {
    Add-Issue $issues 'blocker' 'csv_plan_count_mismatch' '' '' 'csv' "CSV row count ($($csvRows.Count)) does not match plan item count ($($planItems.Count))."
}

$worklistIds = @($worklistItems | ForEach-Object { [string]$_.item_id })
$planIds = @($planItems | ForEach-Object { [string]$_.item_id })
$duplicatePlanIds = @($planIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
$missingPlanIds = @($worklistIds | Where-Object { $planIds -notcontains $_ })
$extraPlanIds = @($planIds | Where-Object { $worklistIds -notcontains $_ })

foreach ($itemId in $duplicatePlanIds) {
    Add-Issue $issues 'blocker' 'duplicate_plan_item' $itemId '' 'item_id' "plan contains duplicate item_id: $itemId"
}
foreach ($itemId in $missingPlanIds) {
    Add-Issue $issues 'blocker' 'missing_plan_item' $itemId '' 'item_id' "worklist item is missing from remediation plan: $itemId"
}
foreach ($itemId in $extraPlanIds) {
    Add-Issue $issues 'blocker' 'extra_plan_item' $itemId '' 'item_id' "plan contains an item that is not in the worklist: $itemId"
}

foreach ($item in $planItems) {
    $expectedWave = Get-Wave $item.category
    if ([int]$item.wave -ne $expectedWave) {
        Add-Issue $issues 'blocker' 'wrong_wave' $item.item_id $item.wave 'wave' "item category '$($item.category)' should be in wave $expectedWave."
    }

    if (Test-Blank $item.relative_path) {
        Add-Issue $issues 'warning' 'blank_relative_path' $item.item_id $item.wave 'relative_path' 'plan item has a blank relative_path.'
    }
}

$groupedWaves = @($planItems | Group-Object wave)
foreach ($group in $groupedWaves) {
    $waveNumber = [int]$group.Name
    $wave = @($waves | Where-Object { [int]$_.wave -eq $waveNumber } | Select-Object -First 1)
    if ($wave.Count -eq 0) {
        Add-Issue $issues 'blocker' 'missing_wave_summary' '' $waveNumber 'waves' "wave $waveNumber is missing from wave summaries."
        continue
    }

    $groupRows = @($group.Group)
    $pendingCount = @($groupRows | Where-Object { $_.status -eq 'pending' }).Count
    $blockerCount = @($groupRows | Where-Object { $_.severity -eq 'blocker' }).Count
    $warningCount = @($groupRows | Where-Object { $_.severity -eq 'warning' }).Count
    $expectedStatus = if ($pendingCount -gt 0) { 'not_ready' } else { 'ready' }

    if ($wave[0].total_files -ne $groupRows.Count) {
        Add-Issue $issues 'blocker' 'wave_total_mismatch' '' $waveNumber 'total_files' "wave $waveNumber total_files ($($wave[0].total_files)) does not match item count ($($groupRows.Count))."
    }
    if ($wave[0].pending_files -ne $pendingCount) {
        Add-Issue $issues 'blocker' 'wave_pending_mismatch' '' $waveNumber 'pending_files' "wave $waveNumber pending_files ($($wave[0].pending_files)) does not match item count ($pendingCount)."
    }
    if ($wave[0].blocker_files -ne $blockerCount) {
        Add-Issue $issues 'warning' 'wave_blocker_mismatch' '' $waveNumber 'blocker_files' "wave $waveNumber blocker_files ($($wave[0].blocker_files)) does not match item count ($blockerCount)."
    }
    if ($wave[0].warning_files -ne $warningCount) {
        Add-Issue $issues 'warning' 'wave_warning_mismatch' '' $waveNumber 'warning_files' "wave $waveNumber warning_files ($($wave[0].warning_files)) does not match item count ($warningCount)."
    }
    if ($wave[0].status -ne $expectedStatus) {
        Add-Issue $issues 'warning' 'wave_status_mismatch' '' $waveNumber 'status' "wave $waveNumber status should be $expectedStatus."
    }
}

foreach ($wave in $waves) {
    if (@($planItems | Where-Object { [int]$_.wave -eq [int]$wave.wave }).Count -eq 0) {
        Add-Issue $issues 'warning' 'empty_wave_summary' '' $wave.wave 'waves' "wave $($wave.wave) has a summary but no plan items."
    }
}

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates the public executable remediation plan and CSV against the source worklist. It does not delete files, quarantine files, change web server config, copy attachments, import records, or switch traffic.'
    overall_status = if (-not $plan -or -not $worklist) { 'missing' } elseif ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        worklist_items = $worklistItems.Count
        plan_items = $planItems.Count
        csv_rows = $csvRows.Count
        waves = $waves.Count
        duplicate_plan_items = $duplicatePlanIds.Count
        missing_plan_items = $missingPlanIds.Count
        extra_plan_items = $extraPlanIds.Count
        blockers = $blockers
        warnings = $warnings
    }
    files = [ordered]@{
        report = $ReportPath
        plan = $PlanPath
        worklist = $WorklistPath
        csv = $CsvPath
    }
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy public executable remediation plan validation written to $ReportPath"
