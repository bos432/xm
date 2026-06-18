param(
    [string]$SqlDump = (Resolve-Path "$PSScriptRoot\..\..\xm_zlck888_com_2026-05-19_18-35-12_mysql_data_W0wH5.sql").Path,
    [string]$LegacyRoot = (Resolve-Path "$PSScriptRoot\..\..").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-attachment-quality.json"),
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

        if ($escape) {
            [void]$current.Append($char)
            $escape = $false
            continue
        }
        if ($char -eq '\') {
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
        if ($char -eq '\') {
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
            if ($escape) { $escape = $false; continue }
            if ($char -eq '\') { $escape = $true; continue }
            if ($char -eq "'") {
                if ($inString -and $i + 1 -lt $content.Length -and $content[$i + 1] -eq "'") { $i++; continue }
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
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $row[$columns[$i]] = if ($i -lt $values.Count) { $values[$i] } else { $null }
            }
            $rows.Add($row)
        }
    }

    return $rows.ToArray()
}

function Get-Extension($path) {
    $value = Convert-EmptyToNull $path
    if (-not $value) { return $null }
    $clean = ([string]$value).Split('?')[0]
    $match = [regex]::Match($clean, '\.([A-Za-z0-9]{1,12})$')
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.ToLowerInvariant()
}

function Resolve-LegacyFile($path) {
    $value = Convert-EmptyToNull $path
    if (-not $value) { return $null }

    $normalized = ([string]$value).Replace('\\', '/').TrimStart('/')
    $candidates = @(
        (Join-Path $LegacyRoot $normalized),
        (Join-Path $LegacyRoot (Join-Path 'upload' $normalized)),
        (Join-Path $LegacyRoot (Join-Path 'public' $normalized)),
        (Join-Path $LegacyRoot (Join-Path 'public\upload' $normalized))
    )

    foreach ($candidate in $candidates | Select-Object -Unique) {
        try {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return Get-Item -LiteralPath $candidate
            }
        } catch {
            continue
        }
    }

    return $null
}

function Parse-AttachmentValue($path, $originalName) {
    $rawValue = Convert-EmptyToNull $path
    $parsedOriginalName = Convert-EmptyToNull $originalName
    $storedPath = $rawValue
    $legacyDate = $null

    if ($rawValue -and [string]$rawValue -match '\|') {
        $parts = @(([string]$rawValue).Split('|') | ForEach-Object { $_.Trim() })
        if ($parts.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
            $storedPath = $parts[1]
        }
        if (-not $parsedOriginalName -and $parts.Count -ge 1) {
            $parsedOriginalName = Convert-EmptyToNull $parts[0]
        }
        if ($parts.Count -ge 3) {
            $legacyDate = Convert-EmptyToNull $parts[2]
        }
    }

    return [pscustomobject][ordered]@{
        raw_path = $rawValue
        stored_path = $storedPath
        original_name = $parsedOriginalName
        legacy_date = $legacyDate
    }
}

function New-AttachmentReference($sourceTable, $legacyId, $legacyProjectId, $field, $path, $originalName) {
    $parsed = Parse-AttachmentValue $path $originalName
    $value = Convert-EmptyToNull $parsed.stored_path
    if (-not $value) { return $null }

    $extension = Get-Extension $value
    $file = Resolve-LegacyFile $value
    $isTraversal = [string]$value -match '(^|[\\/])\.\.([\\/]|$)'
    $isAbsolute = [string]$value -match '^([a-zA-Z]:[\\/]|[\\/]{2}|/|[a-zA-Z]+://)'
    $hasInvalidPathChars = [string]$value -match '[<>:"|*]'
    $dangerousExtensions = @('php','phtml','phar','asp','aspx','asa','cer','jsp','jspx','war','sh','bash','bat','cmd','ps1','psm1','exe','dll','com','scr','msi','jar','pl','py','rb')

    $warnings = New-Object System.Collections.Generic.List[string]
    if (-not $file) { $warnings.Add('missing_file') }
    if ($isTraversal) { $warnings.Add('path_traversal') }
    if ($isAbsolute) { $warnings.Add('absolute_or_url_path') }
    if ($hasInvalidPathChars) { $warnings.Add('invalid_path_chars') }
    if ($extension -and $dangerousExtensions.Contains($extension)) { $warnings.Add('dangerous_extension') }
    if ($file -and $file.Length -eq 0) { $warnings.Add('zero_byte_file') }

    return [pscustomobject][ordered]@{
        source_table = $sourceTable
        legacy_id = $legacyId
        legacy_project_id = $legacyProjectId
        field = $field
        path = $value
        raw_path = $parsed.raw_path
        original_name = $parsed.original_name
        legacy_date = $parsed.legacy_date
        extension = $extension
        exists = [bool]$file
        size = if ($file) { $file.Length } else { $null }
        resolved_path = if ($file) { $file.FullName } else { $null }
        warnings = @($warnings)
    }
}

if (-not (Test-Path -LiteralPath $SqlDump)) { throw "SQL dump not found: $SqlDump" }
if (-not (Test-Path -LiteralPath $LegacyRoot)) { throw "Legacy root not found: $LegacyRoot" }

$content = Get-Content -LiteralPath $SqlDump -Raw -Encoding UTF8
$references = New-Object System.Collections.Generic.List[object]

foreach ($row in @(Get-TableRows $content 'pro_file')) {
    $legacyProjectId = $null
    if (Convert-EmptyToNull $row.pro_id) { $legacyProjectId = [int]$row.pro_id }
    $reference = New-AttachmentReference 'pro_file' ([int]$row.id) $legacyProjectId 'fname' $row.fname $row.name
    if ($reference) { $references.Add($reference) }
}

foreach ($row in @(Get-TableRows $content 'pro_pro')) {
    foreach ($field in @('file0','file1','file2','file3','file4','file5','file6','file7','file8','file9')) {
        $reference = New-AttachmentReference 'pro_pro' ([int]$row.id) ([int]$row.id) $field $row[$field] $null
        if ($reference) { $references.Add($reference) }
    }
}

$warningReferences = New-Object System.Collections.Generic.List[object]
$dangerousReferences = New-Object System.Collections.Generic.List[object]
$missingReferences = New-Object System.Collections.Generic.List[object]
$zeroByteReferences = New-Object System.Collections.Generic.List[object]
$missingSamples = New-Object System.Collections.Generic.List[object]
$dangerousSamples = New-Object System.Collections.Generic.List[object]
$zeroByteSamples = New-Object System.Collections.Generic.List[object]
$warningSamples = New-Object System.Collections.Generic.List[object]
$sourceCounts = [ordered]@{}
$extensionCounts = @{}
$pathCounts = @{}
$existingFileCount = 0
foreach ($reference in $references) {
    $sourceKey = if (Convert-EmptyToNull $reference.source_table) { [string]$reference.source_table } else { '(none)' }
    $extensionKey = if (Convert-EmptyToNull $reference.extension) { [string]$reference.extension } else { '(none)' }
    if (-not $sourceCounts.Contains($sourceKey)) { $sourceCounts[$sourceKey] = 0 }
    if (-not $extensionCounts.ContainsKey($extensionKey)) { $extensionCounts[$extensionKey] = 0 }
    $sourceCounts[$sourceKey]++
    $extensionCounts[$extensionKey]++

    if ($reference.exists) { $existingFileCount++ }
    if (Convert-EmptyToNull $reference.path) {
        $pathKey = [string]$reference.path
        if (-not $pathCounts.ContainsKey($pathKey)) { $pathCounts[$pathKey] = 0 }
        $pathCounts[$pathKey]++
    }

    if ($reference.warnings.Count -gt 0) {
        $warningReferences.Add($reference)
        if ($warningSamples.Count -lt $SampleSize) { $warningSamples.Add($reference) }
    }
    if ($reference.warnings -contains 'dangerous_extension') {
        $dangerousReferences.Add($reference)
        if ($dangerousSamples.Count -lt $SampleSize) { $dangerousSamples.Add($reference) }
    }
    if ($reference.warnings -contains 'missing_file') {
        $missingReferences.Add($reference)
        if ($missingSamples.Count -lt $SampleSize) { $missingSamples.Add($reference) }
    }
    if ($reference.warnings -contains 'zero_byte_file') {
        $zeroByteReferences.Add($reference)
        if ($zeroByteSamples.Count -lt $SampleSize) { $zeroByteSamples.Add($reference) }
    }
}
$bySource = @($sourceCounts.GetEnumerator() | ForEach-Object { [ordered]@{ source_table = $_.Key; count = $_.Value } })
$byExtension = @($extensionCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { [ordered]@{ extension = $_.Key; count = $_.Value } })
$duplicatePaths = @($pathCounts.GetEnumerator() | Where-Object { $_.Value -gt 1 } | Sort-Object Value -Descending | Select-Object -First $SampleSize | ForEach-Object { [ordered]@{ path = $_.Key; count = $_.Value } })
$missingSampleArray = @($missingSamples.ToArray())
$dangerousSampleArray = @($dangerousSamples.ToArray())
$zeroByteSampleArray = @($zeroByteSamples.ToArray())
$warningSampleArray = @($warningSamples.ToArray())
$referenceArray = @($references.ToArray())

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    sql_dump = $SqlDump
    legacy_root = $LegacyRoot
    sample_size = $SampleSize
    summary = [ordered]@{
        total_references = $references.Count
        existing_files = $existingFileCount
        missing_files = $missingReferences.Count
        warning_references = $warningReferences.Count
        dangerous_extensions = $dangerousReferences.Count
        zero_byte_files = $zeroByteReferences.Count
        duplicate_path_count = $duplicatePaths.Count
    }
    by_source = $bySource
    by_extension = $byExtension
    duplicate_paths = $duplicatePaths
    samples = [ordered]@{
        missing = $missingSampleArray
        dangerous = $dangerousSampleArray
        zero_byte = $zeroByteSampleArray
        warnings = $warningSampleArray
    }
    references = $referenceArray
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Attachment quality report written to $ReportPath"
