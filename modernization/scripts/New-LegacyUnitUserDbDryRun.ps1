param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$UnitUserMapPath = (Join-Path $PSScriptRoot "legacy-unit-user-id-map.json"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-unit-user-db-dry-run.json"),
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

function New-UnitRecord($row) {
    return [pscustomobject][ordered]@{
        db_status = 'ready_for_import'
        target_table = 'units'
        legacy_id = if (Convert-EmptyToNull $row.id) { [int64]$row.id } else { $null }
        name = $row.unitname
        credit_code = Convert-EmptyToNull $row.unitcode
        contact_name = Convert-EmptyToNull $row.unitlinker
        contact_mobile = Convert-EmptyToNull $row.unitlinkermobile
        email = Convert-EmptyToNull $row.linkermail
        address = ((@($row.unitaddr, $row.detailaddr) | Where-Object { Convert-EmptyToNull $_ }) -join ' ')
        region_code = Convert-EmptyToNull $row.unitaddr
        status = if ($row.state -eq '通过审核') { 'active' } else { 'pending' }
        metadata = [ordered]@{ legacy_state = $row.state; regkind = $row.regkind; regmoney = $row.regmoney; reg_ip = $row.reg_ip; score = $row.score }
        warnings = @()
    }
}

function New-UnitUserRecord($row, $unitUserMap) {
    $legacyUnitId = if (Convert-EmptyToNull $row.id) { [int64]$row.id } else { $null }
    $mappedUnitId = $null
    if ($legacyUnitId -ne $null -and $unitUserMap.ContainsKey([string]$legacyUnitId)) {
        $mapItem = $unitUserMap[[string]$legacyUnitId]
        if (Convert-EmptyToNull $mapItem.unit_id) { $mappedUnitId = [int64]$mapItem.unit_id }
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not $mappedUnitId) { $warnings.Add('unit_id_mapping_required') }
    $warnings.Add('password_reset_required')

    return [pscustomobject][ordered]@{
        db_status = if ($mappedUnitId) { 'ready_for_import' } else { 'ready_for_unit_mapping' }
        target_table = 'users'
        legacy_id = "pro_unit:$($row.id)"
        unit_id = $mappedUnitId
        name = $row.unitname
        username = if (Convert-EmptyToNull $row.unitcode) { $row.unitcode } else { "unit_$($row.id)" }
        email = Convert-EmptyToNull $row.linkermail
        mobile = Convert-EmptyToNull $row.unitlinkermobile
        password = '__RESET_REQUIRED__'
        role = 'unit'
        is_active = ($row.state -eq '通过审核')
        metadata = [ordered]@{ legacy_unit_id = $legacyUnitId; legacy_password_hash = $row.password; requires_password_reset = $true }
        warnings = @($warnings.ToArray())
    }
}

function New-ManageUserRecord($row) {
    $roleMap = @{ '0'='admin'; '1'='county'; '2'='department'; '3'='expert' }
    $role = if ($roleMap.ContainsKey([string]$row.role)) { $roleMap[[string]$row.role] } else { 'department' }
    return [pscustomobject][ordered]@{
        db_status = 'ready_for_import'
        target_table = 'users'
        legacy_id = "pro_manage:$($row.id)"
        unit_id = $null
        name = if (Convert-EmptyToNull $row.nick_name) { $row.nick_name } else { $row.user_name }
        username = $row.user_name
        email = Convert-EmptyToNull $row.email
        mobile = Convert-EmptyToNull $row.phone
        password = '__RESET_REQUIRED__'
        role = $role
        is_active = -not ([string]$row.state -match '禁用|停用|关闭')
        metadata = [ordered]@{ legacy_manage_id = if (Convert-EmptyToNull $row.id) { [int64]$row.id } else { $null }; legacy_password_hash = $row.password; requires_password_reset = $true; region = $row.region; region_id = $row.region_id }
        warnings = @('password_reset_required')
    }
}

function New-RootUserRecord($row) {
    return [pscustomobject][ordered]@{
        db_status = 'ready_for_import'
        target_table = 'users'
        legacy_id = "pro_root:$($row.id)"
        unit_id = $null
        name = $row.username
        username = $row.username
        email = $null
        mobile = $null
        password = '__RESET_REQUIRED__'
        role = 'admin'
        is_active = $true
        metadata = [ordered]@{ legacy_root_id = if (Convert-EmptyToNull $row.id) { [int64]$row.id } else { $null }; legacy_password_hash = $row.password; requires_password_reset = $true }
        warnings = @('password_reset_required')
    }
}

if (-not (Test-Path -LiteralPath $SqlDump)) { throw "SQL dump not found: $SqlDump" }

$content = Get-Content -LiteralPath $SqlDump -Raw -Encoding UTF8
$unitUserMap = @{}
if (Test-Path -LiteralPath $UnitUserMapPath) {
    $mapReport = Get-Content -LiteralPath $UnitUserMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in @($mapReport.items)) {
        if (Convert-EmptyToNull $item.legacy_unit_id) {
            $unitUserMap[[string]$item.legacy_unit_id] = $item
        }
    }
}

$unitRows = @(Get-TableRows $content 'pro_unit')
$manageRows = @(Get-TableRows $content 'pro_manage')
$rootRows = @(Get-TableRows $content 'pro_root')

$unitRecords = New-Object System.Collections.Generic.List[object]
$userRecords = New-Object System.Collections.Generic.List[object]
$unitSamples = New-Object System.Collections.Generic.List[object]
$userSamples = New-Object System.Collections.Generic.List[object]
$userRoleCounts = @{}
$userStatusCounts = @{}
$readyUserCount = 0
$waitingUnitMappingUserCount = 0

foreach ($row in $unitRows) {
    $unit = New-UnitRecord $row
    $unitUser = New-UnitUserRecord $row $unitUserMap
    $unitRecords.Add($unit)
    $userRecords.Add($unitUser)
    if ($unitSamples.Count -lt $SampleSize) { $unitSamples.Add($unit) }
    if ($userSamples.Count -lt $SampleSize) { $userSamples.Add($unitUser) }
}

foreach ($row in $manageRows) {
    $user = New-ManageUserRecord $row
    $userRecords.Add($user)
    if ($userSamples.Count -lt $SampleSize) { $userSamples.Add($user) }
}

foreach ($row in $rootRows) {
    $user = New-RootUserRecord $row
    $userRecords.Add($user)
    if ($userSamples.Count -lt $SampleSize) { $userSamples.Add($user) }
}

foreach ($user in $userRecords) {
    $role = if (Convert-EmptyToNull $user.role) { [string]$user.role } else { '(none)' }
    $status = if ($user.db_status) { [string]$user.db_status } else { '(none)' }
    if (-not $userRoleCounts.ContainsKey($role)) { $userRoleCounts[$role] = 0 }
    if (-not $userStatusCounts.ContainsKey($status)) { $userStatusCounts[$status] = 0 }
    $userRoleCounts[$role]++
    $userStatusCounts[$status]++
    if ($status -eq 'ready_for_import') { $readyUserCount++ }
    if ($status -eq 'ready_for_unit_mapping') { $waitingUnitMappingUserCount++ }
}

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    sql_dump = $SqlDump
    unit_user_map = $UnitUserMapPath
    sample_size = $SampleSize
    summary = [ordered]@{
        total_units = $unitRecords.Count
        ready_units = $unitRecords.Count
        total_users = $userRecords.Count
        ready_users = $readyUserCount
        users_waiting_unit_mapping = $waitingUnitMappingUserCount
        password_reset_required = $userRecords.Count
    }
    user_by_role = @($userRoleCounts.GetEnumerator() | ForEach-Object { [ordered]@{ role = $_.Key; count = $_.Value } })
    user_by_status = @($userStatusCounts.GetEnumerator() | ForEach-Object { [ordered]@{ status = $_.Key; count = $_.Value } })
    samples = [ordered]@{
        units = @($unitSamples.ToArray())
        users = @($userSamples.ToArray())
    }
    units = @($unitRecords.ToArray())
    users = @($userRecords.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Unit/user DB dry-run written to $ReportPath"
