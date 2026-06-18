param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$UnitUserMapPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-project-db-dry-run.json"),
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

function Get-ProjectStatus($row) {
    switch ([string]$row.state_id) {
        '0' { return 'draft' }
        '3' { return 'returned' }
        '52' { return 'returned' }
        '-1' { return 'rejected' }
        '6' { return 'rejected' }
        default { return 'reviewing' }
    }
}

if (-not (Test-Path -LiteralPath $SqlDump)) { throw "SQL dump not found: $SqlDump" }

$content = Get-Content -LiteralPath $SqlDump -Raw -Encoding UTF8
$rows = @(Get-TableRows $content 'pro_pro')
$unitUserMap = @{}
if (Test-Path -LiteralPath $UnitUserMapPath) {
    $mapReport = Get-Content -LiteralPath $UnitUserMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in @($mapReport.items)) {
        if (Convert-EmptyToNull $item.legacy_unit_id) {
            $unitUserMap[[string]$item.legacy_unit_id] = $item
        }
    }
}

$records = New-Object System.Collections.Generic.List[object]
$samples = New-Object System.Collections.Generic.List[object]
$statusCounts = @{}
$categoryCounts = @{}
$missingUnitMapCount = 0
$missingOwnerMapCount = 0
$readyForImportCount = 0

foreach ($row in $rows) {
    $status = Get-ProjectStatus $row
    $category = if (Convert-EmptyToNull $row.pro_kind) { [string]$row.pro_kind } else { '(none)' }
    if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
    if (-not $categoryCounts.ContainsKey($category)) { $categoryCounts[$category] = 0 }
    $statusCounts[$status]++
    $categoryCounts[$category]++

    $legacyUnitId = if (Convert-EmptyToNull $row.claimid) { [int64]$row.claimid } else { $null }
    $mappedUnitId = $null
    $mappedOwnerId = $null
    if ($legacyUnitId -ne $null -and $unitUserMap.ContainsKey([string]$legacyUnitId)) {
        $mapItem = $unitUserMap[[string]$legacyUnitId]
        if (Convert-EmptyToNull $mapItem.unit_id) { $mappedUnitId = [int64]$mapItem.unit_id }
        if (Convert-EmptyToNull $mapItem.owner_id) { $mappedOwnerId = [int64]$mapItem.owner_id }
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not $mappedUnitId) { $warnings.Add('unit_id_mapping_required'); $missingUnitMapCount++ }
    if (-not $mappedOwnerId) { $warnings.Add('owner_id_mapping_required'); $missingOwnerMapCount++ }
    $dbStatus = if ($mappedUnitId -and $mappedOwnerId) { 'ready_for_import' } else { 'ready_for_unit_user_mapping' }
    if ($dbStatus -eq 'ready_for_import') { $readyForImportCount++ }

    $record = [pscustomobject][ordered]@{
        db_status = $dbStatus
        target_table = 'projects'
        legacy_id = if (Convert-EmptyToNull $row.id) { [int64]$row.id } else { $null }
        unit_id = $mappedUnitId
        owner_id = $mappedOwnerId
        legacy_unit_id = $legacyUnitId
        title = $row.proname
        category = Convert-EmptyToNull $row.pro_kind
        project_type = Convert-EmptyToNull $row.prokind
        status = $status
        summary = Convert-EmptyToNull $row.abstract
        budget_amount = Convert-EmptyToNull $row.totalmoney
        submitted_at = Convert-EmptyToNull $row.time
        current_reviewer_role = $null
        metadata = [ordered]@{
            legacy_state = $row.state
            state_id = $row.state_id
            state_id1 = $row.state_id1
            apply_money = $row.apply_money
            guide_code = $row.guide_code
            research_direction = $row.research_direction
        }
        warnings = @($warnings.ToArray())
    }
    $records.Add($record)
    if ($samples.Count -lt $SampleSize) { $samples.Add($record) }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    sql_dump = $SqlDump
    target_table = 'projects'
    sample_size = $SampleSize
    summary = [ordered]@{
        total_records = $records.Count
        ready_for_unit_user_mapping = $records.Count - $readyForImportCount
        ready_for_import = $readyForImportCount
        missing_unit_mapping = $missingUnitMapCount
        missing_owner_mapping = $missingOwnerMapCount
    }
    by_status = @($statusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
    by_category = @($categoryCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { [ordered]@{ category = $_.Key; count = $_.Value } })
    samples = [ordered]@{ records = @($samples.ToArray()) }
    records = @($records.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Project DB dry-run written to $ReportPath"
