param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "legacy-migration-operational-docs-validation.json"),
    [string]$GoLiveDrillReportPath = (Join-Path $PSScriptRoot "legacy-migration-go-live-drill-report.md"),
    [string]$RollbackPlanPath = (Join-Path $PSScriptRoot "legacy-migration-rollback-plan.md"),
    [string]$OperatorRunbookPath = (Join-Path $PSScriptRoot "legacy-migration-operator-runbook.md")
)

$ErrorActionPreference = 'Stop'

function Test-Blank($value) {
    return $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
}

function Add-Issue($issues, $severity, $document, $field, $code, $message) {
    $issues.Add([pscustomobject][ordered]@{
        severity = $severity
        document = $document
        field = $field
        code = $code
        message = $message
    })
}

function Test-Document($issues, $key, $path, $title, $requiredSections, $requiredPhrases) {
    $exists = -not (Test-Blank $path) -and (Test-Path -LiteralPath $path -PathType Leaf)
    $content = ''
    $missingSections = 0
    $missingPhrases = 0
    $placeholderCount = 0
    $lineCount = 0

    if (-not $exists) {
        Add-Issue $issues 'blocker' $key 'path' 'missing_document' "Required operational document is missing: $path"
    } else {
        $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        $lineCount = @($content -split "`r?`n").Count
        $placeholderCount = ([regex]::Matches($content, '\bTBD\b')).Count

        if ($content -notmatch [regex]::Escape($title)) {
            Add-Issue $issues 'blocker' $key 'title' 'missing_title' "Document title is missing: $title"
        }

        foreach ($section in $requiredSections) {
            if ($content -notmatch [regex]::Escape($section)) {
                $missingSections++
                Add-Issue $issues 'blocker' $key 'sections' 'missing_section' "Document is missing required section: $section"
            }
        }

        foreach ($phrase in $requiredPhrases) {
            if ($content -notmatch [regex]::Escape($phrase)) {
                $missingPhrases++
                Add-Issue $issues 'blocker' $key 'safety_phrase' 'missing_safety_phrase' "Document is missing required safety phrase: $phrase"
            }
        }
    }

    return [pscustomobject][ordered]@{
        key = $key
        path = $path
        exists = $exists
        line_count = $lineCount
        placeholder_count = $placeholderCount
        missing_sections = $missingSections
        missing_safety_phrases = $missingPhrases
    }
}

$issues = New-Object System.Collections.Generic.List[object]
$documents = @(
    Test-Document $issues 'go_live_drill_report' $GoLiveDrillReportPath '# Legacy Migration Go-Live Drill Report' @(
        '## 1. Overall Status',
        '## 2. Core Data Scope',
        '## 3. Attachment Dry-Run',
        '## 4. Batch Import Plan',
        '## 5. Preflight Items',
        '## 6. Artifact Manifest',
        '## 7. Drill Sign-Off'
    ) @(
        'Ops owner: TBD',
        'Rollback drill: TBD',
        'Residual risks: TBD'
    )
    Test-Document $issues 'rollback_plan' $RollbackPlanPath '# Legacy Migration Rollback Plan' @(
        '## 1. Rollback Goals',
        '## 2. Rollback Triggers',
        '## 3. Backup Confirmation',
        '## 4. Entry Rollback',
        '## 5. Database Rollback',
        '## 6. Attachment Copy Rollback',
        '## 7. Queue And Scheduler Rollback',
        '## 8. Acceptance Checklist',
        '## 9. Postmortem Notes'
    ) @(
        'Never write back to the legacy database during rollback.',
        'Do not write any rollback data into the legacy database.',
        'Never delete files from the legacy upload directory.'
    )
    Test-Document $issues 'operator_runbook' $OperatorRunbookPath '# Legacy Migration Operator Runbook' @(
        '## 1. Operating Principles',
        '## 2. Report Pipeline',
        '## 3. Validation Commands',
        '## 4. Key Reports',
        '## 5. Real Attachment Copy',
        '## 6. Database Import Preconditions',
        '## 6.1 Database Import Dry-Run Commands',
        '## 7. Go-Live Drill Flow',
        '## 8. Rollback Entry',
        '## 9. Manual Sign-Off'
    ) @(
        'Do not modify legacy business files.',
        'Do not write back to the legacy database.',
        'Real attachment copy must use the explicit Execute flag.',
        'The execute flag intentionally fails until real import is implemented.'
    )
)

$blockers = @($issues.ToArray() | Where-Object { $_.severity -eq 'blocker' }).Count
$warnings = @($issues.ToArray() | Where-Object { $_.severity -eq 'warning' }).Count

$report = [ordered]@{
    generated_at = (Get-Date -Format o)
    mode = 'preview_only'
    note = 'This report validates operational Markdown document structure and required safety phrases. It does not copy files, import records, switch traffic, update templates, or write database records.'
    overall_status = if ($blockers -gt 0) { 'blocked' } elseif ($warnings -gt 0) { 'not_ready' } else { 'ready' }
    summary = [ordered]@{
        documents = @($documents).Count
        existing_documents = @($documents | Where-Object { $_.exists }).Count
        missing_documents = @($documents | Where-Object { -not $_.exists }).Count
        missing_sections = [int](@($documents | ForEach-Object { $_.missing_sections } | Measure-Object -Sum).Sum)
        missing_safety_phrases = [int](@($documents | ForEach-Object { $_.missing_safety_phrases } | Measure-Object -Sum).Sum)
        placeholders = [int](@($documents | ForEach-Object { $_.placeholder_count } | Measure-Object -Sum).Sum)
        blockers = $blockers
        warnings = $warnings
    }
    documents = @($documents)
    issues = @($issues.ToArray())
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Legacy migration operational docs validation written to $ReportPath"
