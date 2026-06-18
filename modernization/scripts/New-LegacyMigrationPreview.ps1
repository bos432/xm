param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-preview.json"),
    [int]$SampleSize = 5
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
        if ($escape) {
            [void]$current.Append($char)
            $escape = $false
            continue
        }
        if ($char -eq '\\') {
            [void]$current.Append($char)
            $escape = $true
            continue
        }
        if ($char -eq "'") {
            if ($inString -and $i + 1 -lt $tuple.Length -and $tuple[$i + 1] -eq "'") {
                [void]$current.Append("'")
                $i++
                continue
            }
            $inString = -not $inString
            continue
        }
        if ($char -eq ',' -and -not $inString) {
            $values.Add((Convert-EmptyToNull $current.ToString()))
            [void]$current.Clear()
            continue
        }
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

        if ($escape) {
            if ($depth -gt 0) { [void]$current.Append($char) }
            $escape = $false
            continue
        }

        if ($char -eq '\\') {
            if ($depth -gt 0) { [void]$current.Append($char) }
            $escape = $true
            continue
        }

        if ($char -eq "'") {
            if ($inString -and $i + 1 -lt $valuesText.Length -and $valuesText[$i + 1] -eq "'") {
                if ($depth -gt 0) { [void]$current.Append("'") }
                $i++
                continue
            }
            if ($depth -gt 0) { [void]$current.Append($char) }
            $inString = -not $inString
            continue
        }

        if (-not $inString -and $char -eq '(') {
            if ($depth -gt 0) { [void]$current.Append($char) }
            $depth++
            continue
        }

        if (-not $inString -and $char -eq ')') {
            $depth--
            if ($depth -eq 0) {
                $tuples.Add($current.ToString())
                [void]$current.Clear()
                continue
            }
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
        if ($markerEnd -ge 0) {
            $statements.Add($content.Substring($start, $markerEnd - $start + 1))
            $offset = $markerEnd + 1
            continue
        }

        $inString = $false
        $escape = $false
        for ($i = $start; $i -lt $content.Length; $i++) {
            $char = $content[$i]

            if ($escape) {
                $escape = $false
                continue
            }

            if ($char -eq '\\') {
                $escape = $true
                continue
            }

            if ($char -eq "'") {
                if ($inString -and $i + 1 -lt $content.Length -and $content[$i + 1] -eq "'") {
                    $i++
                    continue
                }
                $inString = -not $inString
                continue
            }

            if (-not $inString -and $char -eq ';') {
                $statements.Add($content.Substring($start, $i - $start + 1))
                $offset = $i + 1
                break
            }
        }

        if ($i -ge $content.Length) { break }
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

function Get-TableRows($content, $table, $limit) {
    $columns = @(Get-TableColumns $content $table)
    if ($columns.Count -eq 0) { return @() }

    $insertStatements = @(Get-InsertStatements $content $table)
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($statement in $insertStatements) {
        $valuesIndex = $statement.IndexOf('VALUES', [System.StringComparison]::OrdinalIgnoreCase)
        if ($valuesIndex -lt 0) { continue }
        $valuesText = $statement.Substring($valuesIndex + 6).Trim().TrimEnd(';')
        $tuples = @(Split-SqlTuples $valuesText)
        foreach ($tuple in $tuples) {
            $values = @(Split-SqlValues $tuple)
            $row = [ordered]@{}
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $row[$columns[$i]] = if ($i -lt $values.Count) { $values[$i] } else { $null }
            }
            $rows.Add($row)
            if ($rows.Count -ge $limit) { return $rows.ToArray() }
        }
    }

    return $rows.ToArray()
}

function New-Section($sourceTable, $targetTable, $rows, $sampleSize) {
    $warnings = New-Object System.Collections.Generic.List[string]
    if ($rows.Count -eq 0) { $warnings.Add('empty_preview') }
    if ($rows.Count -lt $sampleSize) { $warnings.Add('sample_size_not_reached') }

    foreach ($row in $rows) {
        if ($row.Contains('legacy_id') -and ($null -eq $row.legacy_id -or [string]$row.legacy_id -eq '' -or [string]$row.legacy_id -eq '0')) {
            $warnings.Add('legacy_id_missing_or_zero')
            break
        }
    }

    return [ordered]@{
        source_table = $sourceTable
        target_table = $targetTable
        row_count = $rows.Count
        warnings = @($warnings | Select-Object -Unique)
        rows = $rows
    }
}

function Map-Unit($row) {
    return [ordered]@{
        target_table = 'units'
        legacy_id = [int]$row.id
        name = $row.unitname
        credit_code = Convert-EmptyToNull $row.unitcode
        contact_name = Convert-EmptyToNull $row.unitlinker
        contact_mobile = Convert-EmptyToNull $row.unitlinkermobile
        email = Convert-EmptyToNull $row.linkermail
        address = ((@($row.unitaddr, $row.detailaddr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' ')
        region_code = Convert-EmptyToNull $row.unitaddr
        status = if ($row.state -eq '通过审核') { 'active' } else { 'pending' }
        metadata = [ordered]@{ legacy_state = $row.state; regkind = $row.regkind; regmoney = $row.regmoney; reg_ip = $row.reg_ip; score = $row.score }
    }
}

function Map-UnitUser($row) {
    return [ordered]@{
        target_table = 'users'
        username = if (Convert-EmptyToNull $row.unitcode) { $row.unitcode } else { "unit_$($row.id)" }
        name = $row.unitname
        email = Convert-EmptyToNull $row.linkermail
        mobile = Convert-EmptyToNull $row.unitlinkermobile
        role = 'unit'
        is_active = ($row.state -eq '通过审核')
        metadata = [ordered]@{ legacy_unit_id = [int]$row.id; legacy_password_hash = $row.password; requires_password_reset = $true }
    }
}

function Map-ManageUser($row) {
    $roleMap = @{ '0'='admin'; '1'='county'; '2'='department'; '3'='expert' }
    $role = if ($roleMap.ContainsKey([string]$row.role)) { $roleMap[[string]$row.role] } else { 'department' }
    return [ordered]@{
        target_table = 'users'
        username = $row.user_name
        name = if (Convert-EmptyToNull $row.nick_name) { $row.nick_name } else { $row.user_name }
        email = Convert-EmptyToNull $row.email
        mobile = Convert-EmptyToNull $row.phone
        role = $role
        is_active = -not ([string]$row.state -match '禁用|停用|关闭')
        metadata = [ordered]@{ legacy_manage_id = [int]$row.id; legacy_password_hash = $row.password; requires_password_reset = $true; region = $row.region; region_id = $row.region_id }
    }
}

function Map-RootUser($row) {
    return [ordered]@{
        target_table = 'users'
        username = $row.username
        name = $row.username
        role = 'admin'
        is_active = $true
        metadata = [ordered]@{ legacy_root_id = [int]$row.id; legacy_password_hash = $row.password; requires_password_reset = $true }
    }
}

function Map-Project($row) {
    $stateId = [string]$row.state_id
    $status = switch ($stateId) {
        '0' { 'draft'; break }
        '3' { 'returned'; break }
        '52' { 'returned'; break }
        '-1' { 'rejected'; break }
        '6' { 'rejected'; break }
        default { 'reviewing' }
    }
    return [ordered]@{
        target_table = 'projects'
        legacy_id = [int]$row.id
        legacy_unit_id = [int]$row.claimid
        title = $row.proname
        category = [string]$row.pro_kind
        project_type = [string]$row.prokind
        status = $status
        summary = Convert-EmptyToNull $row.abstract
        budget_amount = Convert-EmptyToNull $row.totalmoney
        submitted_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ legacy_state = $row.state; state_id = $row.state_id; state_id1 = $row.state_id1; apply_money = $row.apply_money; guide_code = $row.guide_code; research_direction = $row.research_direction; file_fields_present = (@('file0','file1','file2','file3','file4','file5','file6','file7','file8','file9') | Where-Object { Convert-EmptyToNull $row[$_] }) }
    }
}

function Map-ProjectFile($row) {
    $extension = $null
    $source = if (Convert-EmptyToNull $row.fname) { $row.fname } else { $row.name }
    if ($source -and $source.Contains('.')) { $extension = ($source.Split('.')[-1]).ToLowerInvariant() }
    return [ordered]@{
        target_table = 'project_files'
        legacy_id = [int]$row.id
        legacy_project_id = if (Convert-EmptyToNull $row.pro_id) { [int]$row.pro_id } else { $null }
        path = Convert-EmptyToNull $row.fname
        original_name = Convert-EmptyToNull $row.name
        extension = $extension
        purpose = 'legacy_pro_file'
        metadata = [ordered]@{ type = $row.type; state_id = $row.state_id; state_id1 = $row.state_id1; check_time = $row.check_time; check_id = $row.check_id; pifu = $row.pifu }
    }
}

function Map-Review($row) {
    return [ordered]@{
        target_table = 'project_reviews'
        legacy_id = "pro_review:$($row.id)"
        legacy_project_id = if (Convert-EmptyToNull $row.pro_id) { [int]$row.pro_id } else { [int]$row.project_id }
        legacy_reviewer_id = Convert-EmptyToNull $row.expert_id
        stage = 'expert'
        decision = 'reviewed'
        score = Convert-EmptyToNull $row.score
        comment = if (Convert-EmptyToNull $row.comment) { $row.comment } else { $row.content }
        reviewed_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ source_table = 'pro_review'; legacy_user_id = $row.user_id; img1 = $row.img1; img2 = $row.img2 }
    }
}

function Map-CheckLog($row) {
    return [ordered]@{
        target_table = 'project_reviews'
        legacy_id = "pro_check_log:$($row.id)"
        legacy_project_id = if (Convert-EmptyToNull $row.pro_id) { [int]$row.pro_id } else { $null }
        legacy_reviewer_id = Convert-EmptyToNull $row.user_id
        stage = Convert-EmptyToNull $row.role_name
        decision = if (Convert-EmptyToNull $row.state) { $row.state } else { 'logged' }
        comment = Convert-EmptyToNull $row.pifu
        reviewed_at = Convert-EmptyToNull $row.time
        metadata = [ordered]@{ source_table = 'pro_check_log'; state_id = $row.state_id; role_id = $row.role_id; nickname = $row.nikc_name }
    }
}

if (-not (Test-Path -LiteralPath $SqlDump)) { throw "SQL dump not found: $SqlDump" }

$content = Get-Content -LiteralPath $SqlDump -Raw -Encoding UTF8
$sections = @(
    New-Section 'pro_unit' 'units' @(Get-TableRows $content 'pro_unit' $SampleSize | ForEach-Object { Map-Unit $_ }) $SampleSize
    New-Section 'pro_unit' 'users' @(Get-TableRows $content 'pro_unit' $SampleSize | ForEach-Object { Map-UnitUser $_ }) $SampleSize
    New-Section 'pro_manage' 'users' @(Get-TableRows $content 'pro_manage' $SampleSize | ForEach-Object { Map-ManageUser $_ }) $SampleSize
    New-Section 'pro_root' 'users' @(Get-TableRows $content 'pro_root' $SampleSize | ForEach-Object { Map-RootUser $_ }) $SampleSize
    New-Section 'pro_pro' 'projects' @(Get-TableRows $content 'pro_pro' $SampleSize | ForEach-Object { Map-Project $_ }) $SampleSize
    New-Section 'pro_file' 'project_files' @(Get-TableRows $content 'pro_file' $SampleSize | ForEach-Object { Map-ProjectFile $_ }) $SampleSize
    New-Section 'pro_review' 'project_reviews' @(Get-TableRows $content 'pro_review' $SampleSize | ForEach-Object { Map-Review $_ }) $SampleSize
    New-Section 'pro_check_log' 'project_reviews' @(Get-TableRows $content 'pro_check_log' $SampleSize | ForEach-Object { Map-CheckLog $_ }) $SampleSize
)

$previewWarnings = @($sections | ForEach-Object { $_.warnings } | Where-Object { $_ } | Select-Object -Unique)

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    sql_dump = $SqlDump
    sample_size = $SampleSize
    section_count = $sections.Count
    summary = [ordered]@{
        total_sections = $sections.Count
        empty_sections = @($sections | Where-Object { $_.row_count -eq 0 }).Count
        warning_sections = @($sections | Where-Object { $_.warnings.Count -gt 0 }).Count
        warning_count = $previewWarnings.Count
    }
    warnings = $previewWarnings
    sections = $sections
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Preview written to $ReportPath"
