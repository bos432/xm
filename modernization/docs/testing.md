# Testing and Verification

This document defines the verification path for the modernization workspace. The legacy ThinkPHP site should remain unchanged while these checks run against the isolated `modernization` tree.

## Current Lightweight Checks

Use these checks when backend Composer dependencies are not installed yet.

```powershell
php -l modernization\backend\bootstrap\app.php
php -l modernization\backend\app\Console\Commands\ImportLegacyRecords.php
php -l modernization\backend\app\Services\LegacyRecordImportService.php
```

Frontend verification can run independently when Node dependencies are available.

```powershell
cd modernization\frontend
npm run build
```

The current build may report Rolldown chunk-size and VueUse annotation warnings. Treat new errors as blockers, but those known warnings do not currently block the build.

## Restore Backend Dependencies

Install Composer on the test machine, then restore the Laravel backend dependencies.

```powershell
cd modernization\backend
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate
```

The test suite uses `phpunit.xml` defaults for an in-memory SQLite database, array cache/session stores, and a synchronous queue.

```powershell
cd modernization\backend
php artisan test
```

## Legacy Migration Dry Runs

Rebuild non-destructive migration reports before previewing database import plans.

```powershell
PowerShell -ExecutionPolicy Bypass -File modernization\scripts\Invoke-LegacyMigrationReportPipeline.ps1
```

After backend dependencies are installed, preview the Laravel-side import plans without writing records.

```powershell
cd modernization\backend
php artisan legacy:import-records all
php artisan legacy:import-records project_files
php artisan legacy:import-records all --output=../scripts/legacy-record-import-plan.json
```

The `legacy:import-records` command is dry-run only. `--execute` is intentionally rejected until real database imports are implemented and separately verified.
Use `--output` during migration rehearsals when the Laravel-side preview should be archived or exposed to the readiness dashboard.

## Release Gate

Before test-environment release, the minimum gate is:

- Backend dependencies restored with `composer install`.
- `php artisan test` passes.
- `npm run build` passes.
- Migration reports rebuild successfully.
- `php artisan legacy:import-records all --output=../scripts/legacy-record-import-plan.json` reports no unexpected blockers.
- Upload, download, cross-unit access, and login throttling are manually checked from the acceptance checklist.
