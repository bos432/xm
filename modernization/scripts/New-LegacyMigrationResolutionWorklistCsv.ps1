param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.csv"),
    [string]$WorklistPath = (Join-Path $PSScriptRoot "legacy-migration-resolution-worklist.json")
)

$ErrorActionPreference = 'Stop'

function Read-JsonReport($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Format-SampleRows($rows) {
    $items = @()
    foreach ($row in @($rows)) {
        $items += "#$($row.row_number):$($row.legacy_id)"
    }
    return ($items -join ';')
}

$worklist = Read-JsonReport $WorklistPath
$rows = New-Object System.Collections.Generic.List[object]

if ($worklist -and $worklist.items) {
    foreach ($item in @($worklist.items)) {
        $rows.Add([pscustomobject][ordered]@{
            priority = $item.priority
            owner = $item.owner
            template = $item.template
            target = $item.target
            field_group = $item.field_group
            status = $item.status
            row_count = $item.row_count
            sample_rows = Format-SampleRows $item.sample_rows
            action = $item.action
            acceptance = $item.acceptance
        })
    }
}

@($rows.ToArray()) | Export-Csv -LiteralPath $CsvPath -Encoding UTF8 -NoTypeInformation
Write-Host "Legacy migration resolution worklist CSV written to $CsvPath"
