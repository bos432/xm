param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$ProjectDryRunPath = (Join-Path $PSScriptRoot "legacy-project-db-dry-run.json"),
    [string]$ProjectIdMapPath = (Join-Path $PSScriptRoot "legacy-project-id-map.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-workflow-db-dry-run.json"),
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'

function Convert-EmptyToNull($value) {
    if ($null -eq $value) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    if ([string]$value -eq 'NULL') { return $null }
    return $value
}

function Split-SqlValues($tuple) {
    $values = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inString = $false
    $escape = $false
    for ($i = 0; $i -lt $tuple.Length; $i++) {
        $char = $tuple[$i]
        if ($escape) { [void]$current.Append($char); $escape = $false; continue }
        if ($char -eq '\') { [void]$current.Append($char); $escape = $true; continue }
        if ($char -eq "'") {
            if ($inString -and $i + 1 -lt $tuple.Length -and $tuple[$i + 1] -eq "'") { [void]$current.Append("'"); $i++; continue }
            $inString = -not $inString
            continue
        }
        if ($char -eq ',' -and -not $inString) { $values.Add((Convert-EmptyToNull $current.ToString())); [void]$current.Clear(); continue }
        [void]$current.Append($char)
    }
    $values.Add((Convert-EmptyToNull $current.ToString()))
    return $values.ToArray()
}

function Split-SqlTuples($valuesText) {
    $tuples = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $depth = 0
    $inString = $false
    $escape = $false
    for ($i = 0; $i -lt $valuesText.Length; $i++) {
        $char = $valuesText[$i]
        if ($escape) { if ($depth -gt 0) { [void]$current.Append($char) }; $escape = $false; continue }
        if ($char -eq '\') { if ($depth -gt 0) { [void]$current.Append($char) }; $escape = $true; continue }
        if ($char -eq "'") {
            if ($inString -and $i + 1 -lt $valuesText.Length -and $valuesText[$i + 1] -eq "'") { if ($depth -gt 0) { [void]$current.Append("'") }; $i++; continue }
            if ($depth -gt 0) { [void]$current.Append($char) }
            $inString = -not $inString
            continue
        }
        if (-not $inString -and $char -eq '(') { if ($depth -gt 0) { [void]$current.Append($char) }; $depth++; continue }
        if (-not $inString -and $char -eq ')') {
            $depth--
            if ($depth -eq 0) { $tuples.Add($current.ToString()); [void]$current.Clear(); continue }
            if ($depth -gt 0) { [void]$current.Append($char) }
            continue
        }
        if ($depth -gt 0) { [void]$current.Append($char) }
    }
    return $tuples.ToArray()
}

function Get-InsertStatements($content, $table) {
    $tick = [char]96
    $needle = 'INSERT INTO ' + $tick + $table + $tick
    $marker = ';' + "`r`n" + '/*!40000 ALTER TABLE ' + $tick + $table + $tick + ' ENABLE KEYS */'
    $markerAlt = ';' + "`n" + '/*!40000 ALTER TABLE ' + $tick + $table + $tick + ' ENABLE KEYS */'
    $statements = New-Object System.Collections.Generic.List[string]
    $offset = 0
    while ($offset -lt $content.Length) {
        $start = $content.IndexOf($needle, $offset, [System.StringComparison]::OrdinalIgnoreCase)
        if ($start -lt 0) { break }
        $markerEnd = $content.IndexOf($marker, $start, [System.StringComparison]::OrdinalIgnoreCase)
        if ($markerEnd -lt 0) { $markerEnd = $content.IndexOf($markerAlt, $start, [System.StringComparison]::OrdinalIgnoreCase) }
        if ($markerEnd -ge 0) { $statements.Add($content.Substring($start, $markerEnd - $start + 1)); $offset = $markerEnd + 1; continue }
        break
    }
    return $statements.ToArray()
}

function Get-TableColumns($content, $table) {
    $tick = [char]96
    $pattern = 'CREATE TABLE ' + $tick + [regex]::Escape($table) + $tick + ' \((.*?)\) ENGINE'
    $match = [regex]::Match($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return @() }
    return $match.Groups[1].Value -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.StartsWith($tick) } |
        ForEach-Object {
            $columnMatch = [regex]::Match($_, '^' + $tick + '([^' + $tick + ']+)' + $tick)
            if ($columnMatch.Success) { $columnMatch.Groups[1].Value }
        }
}

function Get-TableRows($content, $table) {
    $columns = @(Get-TableColumns $content $table)
    if ($columns.Count -eq 0) { return @() }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($statement in @(Get-InsertStatements $content $table)) {
        $valuesIndex = $statement.IndexOf('VALUES', [System.StringComparison]::OrdinalIgnoreCase)
        if ($valuesIndex -lt 0) { continue }
        $valuesText = $statement.Substring($valuesIndex + 6).Trim().TrimEnd(';')
        foreach ($tuple in @(Split-SqlTuples $valuesText)) {
            $values = @(Split-SqlValues $tuple)
            $row = [ordered]@{}
            for ($i = 0; $i -lt $columns.Count; $i++) { $row[$columns[$i]] = if ($i -lt $values.Count) { $values[$i] } else { $null } }
            $rows.Add([pscustomobject]$row)
        }
    }
    return $rows.ToArray()
}

function Convert-ToInt64OrNull($value) {
    $clean = Convert-EmptyToNull $value
    if (-not $clean) { return $null }
    try { return [int64]$clean } catch { return $null }
}

function Get-TextExcerpt($value, $maxLength = 180) {
    $clean = Convert-EmptyToNull $value
    if (-not $clean) { return $null }
    $text = [regex]::Replace([string]$clean, '<[^>]+>', ' ')
    $text = [regex]::Replace($text, 'data:image/[^;]+;base64[^\s]+', '[base64-image]')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt $maxLength) { return $text.Substring(0, $maxLength) + '...' }
    return $text
}

function Add-Count($counts, $key) {
    if (-not $key) { $key = '(none)' }
    if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
    $counts[$key]++
}

if (-not (Test-Path -LiteralPath $SqlDump)) { throw "SQL dump not found: $SqlDump" }

$content = Get-Content -LiteralPath $SqlDump -Raw -Encoding UTF8
$projectIdMap = @{}
$knownProjectIds = @{}
if (Test-Path -LiteralPath $ProjectDryRunPath) {
    $projectDryRun = Get-Content -LiteralPath $ProjectDryRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($record in @($projectDryRun.records)) {
        if (Convert-EmptyToNull $record.legacy_id) { $knownProjectIds[[string]$record.legacy_id] = $true }
    }
}
if (Test-Path -LiteralPath $ProjectIdMapPath) {
    $mapReport = Get-Content -LiteralPath $ProjectIdMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in @($mapReport.items)) {
        if (Convert-EmptyToNull $item.legacy_project_id) { $knownProjectIds[[string]$item.legacy_project_id] = $true }
        if (Convert-EmptyToNull $item.legacy_project_id -and Convert-EmptyToNull $item.new_project_id) {
            $projectIdMap[[string]$item.legacy_project_id] = [int64]$item.new_project_id
        }
    }
}

$reviewRecords = New-Object System.Collections.Generic.List[object]
$logRecords = New-Object System.Collections.Generic.List[object]
$reviewSamples = New-Object System.Collections.Generic.List[object]
$logSamples = New-Object System.Collections.Generic.List[object]
$reviewStatusCounts = @{}
$reviewSourceCounts = @{}
$logKindCounts = @{}
$missingProjectMapCount = 0
$missingReviewerMapCount = 0
$orphanProjectReferenceCount = 0
$readyReviewCount = 0

foreach ($row in @(Get-TableRows $content 'pro_review')) {
    $legacyProjectId = Convert-ToInt64OrNull $(if (Convert-EmptyToNull $row.pro_id) { $row.pro_id } else { $row.project_id })
    $projectId = if ($legacyProjectId -ne $null -and $projectIdMap.ContainsKey([string]$legacyProjectId)) { $projectIdMap[[string]$legacyProjectId] } else { $null }
    $legacyReviewerId = Convert-ToInt64OrNull $(if (Convert-EmptyToNull $row.expert_id) { $row.expert_id } else { $row.user_id })
    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not $projectId) {
        if ($legacyProjectId -ne $null -and -not $knownProjectIds.ContainsKey([string]$legacyProjectId)) { $warnings.Add('orphan_project_reference'); $orphanProjectReferenceCount++ }
        else { $warnings.Add('project_id_mapping_required'); $missingProjectMapCount++ }
    }
    if ($legacyReviewerId -ne $null) { $warnings.Add('reviewer_id_mapping_required'); $missingReviewerMapCount++ }
    $dbStatus = if ($projectId) { 'ready_for_reviewer_mapping' } else { 'ready_for_project_mapping' }
    if ($projectId) { $readyReviewCount++ }
    $record = [pscustomobject][ordered]@{
        db_status = $dbStatus
        target_table = 'project_reviews'
        legacy_id = "pro_review:$($row.id)"
        project_id = $projectId
        legacy_project_id = $legacyProjectId
        reviewer_id = $null
        legacy_reviewer_id = $legacyReviewerId
        source_table = 'pro_review'
        review_type = 'expert_review'
        stage = 'expert'
        decision = Convert-EmptyToNull $row.comment
        score = Convert-EmptyToNull $row.score
        comment_excerpt = Get-TextExcerpt $row.content
        reviewed_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ legacy_project_id_field = $row.project_id; legacy_pro_id_field = $row.pro_id; has_img1 = [bool](Convert-EmptyToNull $row.img1); has_img2 = [bool](Convert-EmptyToNull $row.img2) }
        warnings = @($warnings.ToArray())
    }
    $reviewRecords.Add($record)
    Add-Count $reviewStatusCounts $dbStatus
    Add-Count $reviewSourceCounts 'pro_review'
    if ($reviewSamples.Count -lt $SampleSize) { $reviewSamples.Add($record) }
}

foreach ($row in @(Get-TableRows $content 'pro_check_log')) {
    $legacyProjectId = Convert-ToInt64OrNull $row.pro_id
    $projectId = if ($legacyProjectId -ne $null -and $projectIdMap.ContainsKey([string]$legacyProjectId)) { $projectIdMap[[string]$legacyProjectId] } else { $null }
    $legacyReviewerId = Convert-ToInt64OrNull $row.user_id
    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not $projectId) {
        if ($legacyProjectId -ne $null -and -not $knownProjectIds.ContainsKey([string]$legacyProjectId)) { $warnings.Add('orphan_project_reference'); $orphanProjectReferenceCount++ }
        else { $warnings.Add('project_id_mapping_required'); $missingProjectMapCount++ }
    }
    if ($legacyReviewerId -ne $null) { $warnings.Add('reviewer_id_mapping_required'); $missingReviewerMapCount++ }
    $dbStatus = if ($projectId) { 'ready_for_reviewer_mapping' } else { 'ready_for_project_mapping' }
    if ($projectId) { $readyReviewCount++ }
    $record = [pscustomobject][ordered]@{
        db_status = $dbStatus
        target_table = 'project_reviews'
        legacy_id = "pro_check_log:$($row.id)"
        project_id = $projectId
        legacy_project_id = $legacyProjectId
        reviewer_id = $null
        legacy_reviewer_id = $legacyReviewerId
        source_table = 'pro_check_log'
        review_type = 'workflow_transition'
        stage = Convert-EmptyToNull $row.role_name
        decision = Convert-EmptyToNull $row.state
        score = $null
        comment_excerpt = Get-TextExcerpt $row.pifu
        reviewed_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ legacy_state_id = $row.state_id; legacy_role_id = $row.role_id; legacy_actor_name = $row.nikc_name }
        warnings = @($warnings.ToArray())
    }
    $reviewRecords.Add($record)
    Add-Count $reviewStatusCounts $dbStatus
    Add-Count $reviewSourceCounts 'pro_check_log'
    if ($reviewSamples.Count -lt $SampleSize) { $reviewSamples.Add($record) }
}

foreach ($row in @(Get-TableRows $content 'pro_log')) {
    $record = [pscustomobject][ordered]@{
        db_status = 'ready_for_import'
        target_table = 'operation_logs'
        legacy_id = "pro_log:$($row.id)"
        actor_id = $null
        legacy_actor_id = Convert-EmptyToNull $row.user_id
        actor_kind = Convert-EmptyToNull $row.user_kind
        action = Get-TextExcerpt $row.what 220
        ip = Convert-EmptyToNull $row.ip
        occurred_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ ex2 = $row.ex2; ex3 = $row.ex3; ex4 = $row.ex4; ex5 = $row.ex5 }
        warnings = @('actor_id_preserved_as_legacy_metadata')
    }
    $logRecords.Add($record)
    Add-Count $logKindCounts $record.actor_kind
    if ($logSamples.Count -lt $SampleSize) { $logSamples.Add($record) }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'dry_run'
    note = 'This report previews workflow review and operation log rows only. It does not import records or write database records.'
    sql_dump = $SqlDump
    project_dry_run = $ProjectDryRunPath
    project_id_map = $ProjectIdMapPath
    sample_size = $SampleSize
    summary = [ordered]@{
        review_records = $reviewRecords.Count
        review_ready_for_import = 0
        review_ready_for_reviewer_mapping = $readyReviewCount
        review_ready_for_project_mapping = $reviewRecords.Count - $readyReviewCount
        operation_log_records = $logRecords.Count
        operation_log_ready_for_import = $logRecords.Count
        project_id_mapping_required = $missingProjectMapCount
        reviewer_id_mapping_required = $missingReviewerMapCount
        orphan_project_references = $orphanProjectReferenceCount
    }
    review_by_status = @($reviewStatusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
    review_by_source = @($reviewSourceCounts.GetEnumerator() | ForEach-Object { [ordered]@{ source_table = $_.Key; count = $_.Value } })
    operation_log_by_actor_kind = @($logKindCounts.GetEnumerator() | ForEach-Object { [ordered]@{ actor_kind = $_.Key; count = $_.Value } })
    samples = [ordered]@{ reviews = @($reviewSamples.ToArray()); operation_logs = @($logSamples.ToArray()) }
    reviews = @($reviewRecords.ToArray())
    operation_logs = @($logSamples.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Workflow DB dry-run written to $ReportPath"
