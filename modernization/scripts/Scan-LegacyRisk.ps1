param(
    [string]$SiteRoot = (Resolve-Path "$PSScriptRoot\..\..").Path,
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-risk-report.txt")
)

$ErrorActionPreference = 'Stop'

$publicRoots = @('upload', 'uploads', 'img', 'images', 'js', 'css', 'excel', 'ueditor', 'public')
$scriptExtensions = @('*.php', '*.phtml', '*.phar', '*.asp', '*.aspx', '*.jsp')
$dangerPatterns = @(
    'eval\s*\(',
    'assert\s*\(',
    'base64_decode\s*\(',
    'shell_exec\s*\(',
    'system\s*\(',
    'passthru\s*\(',
    'preg_replace\s*\(.+/e',
    'file_put_contents\s*\(',
    'move_uploaded_file\s*\('
)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Legacy risk scan")
$lines.Add("SiteRoot: $SiteRoot")
$lines.Add("GeneratedAt: $(Get-Date -Format o)")
$lines.Add('')

$lines.Add('[Executable files in public/upload roots]')
foreach ($root in $publicRoots) {
    $path = Join-Path $SiteRoot $root
    if (-not (Test-Path $path)) { continue }

    foreach ($extension in $scriptExtensions) {
        Get-ChildItem -LiteralPath $path -Recurse -File -Filter $extension -ErrorAction SilentlyContinue |
            ForEach-Object { $lines.Add($_.FullName) }
    }
}

$lines.Add('')
$lines.Add('[Dangerous patterns in PHP files]')
$phpFiles = Get-ChildItem -LiteralPath $SiteRoot -Recurse -File -Filter '*.php' -ErrorAction SilentlyContinue
foreach ($pattern in $dangerPatterns) {
    $matches = $phpFiles | Select-String -Pattern $pattern -CaseSensitive:$false -ErrorAction SilentlyContinue
    foreach ($match in $matches) {
        $lines.Add("$($match.Path):$($match.LineNumber): $($match.Line.Trim())")
    }
}

$lines.Add('')
$lines.Add('[Infected or backup leftovers]')
Get-ChildItem -LiteralPath $SiteRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '\.infected$|\.bak$|bak_|backup|old|\.zip\.php$|\.png\.php$' } |
    ForEach-Object { $lines.Add($_.FullName) }

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Report written to $ReportPath"

