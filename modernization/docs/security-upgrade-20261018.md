# Dependency Security Upgrade (2026-10-18)

## Scope and Release Status

This is a candidate change on the isolated `codex/composer-security-fix` branch. It has not been merged, pushed, or deployed. Production remains on its existing release until the hosted quality gate and production change review are complete.

## Changes

- Upgrade Laravel from 11.x to 12.70.0. The audited Laravel advisories include affected Laravel 11 versions; the fixed lines require Laravel 12.60.0 or later.
- Upgrade PHPUnit from 11.2.6 to 11.5.57, beyond the 11.5.50 advisory fix.
- Upgrade compatible development dependencies, including Collision 8.9.5.
- Relax the direct Symfony Console constraint from `7.3.*` to `^7.3`; Laravel 12 resolves Symfony Console 7.4.21.
- Pin transitive `postcss-selector-parser` to 7.1.6 using npm overrides, retaining ESLint plugin Vue 9 rather than taking an unnecessary major upgrade.
- Add the `Modernization Quality Gate` GitHub Actions workflow for PHP tests/format/audit, frontend audit/lint/tests/typecheck/build, migration SQL dry-run, route registration and isolated deploy rollback tests.

## Local Verification

In the isolated worktree:

- PHP 8.3.30, PHPUnit 11.5.57: `vendor/bin/phpunit --no-coverage` -> **231 tests, 1050 assertions, OK**.
- PHP syntax: 88 application PHP files -> **PASS**.
- Composer audit -> **No security vulnerability advisories found**.
- npm audit -> **found 0 vulnerabilities**.
- Frontend lint, 5 Node tests, utility typecheck and production build -> **PASS**.
- Migration SQL dry-run against in-memory SQLite and API route registration -> **PASS**.
- `bash modernization/deploy/tests/deploy-rollback-test.sh` -> **Deployment isolation and rollback checks passed**.
- `git diff --check` -> **PASS**.

## Known Verification Caveats

- Windows `php artisan test` presents 231 `file_get_contents` warnings from its console reporter even though the same PHPUnit suite is clean. Linux CLI verification is needed to distinguish the terminal/path display issue from the underlying test runner.
- Full Pint check on this Windows checkout reports pre-existing repository-wide line-ending/style differences. Format-only churn is not included in this security change and Pint is not used as a release gate here.
- The in-memory migration dry-run does not apply migrations to production or prove production schema parity.
- No production database, credentials, queue worker, mail provider, OSS bucket, or business records were changed or tested in this upgrade.

## Release Gate

Do not deploy until the GitHub Actions workflow passes on the exact commit. Then stage the candidate against a restored database/files snapshot, verify six-role review and acceptance workflows, queue worker health, SMTP test delivery, OSS upload/download and restore, and rollback. Deploy only the `nxm.zlck888.com` release directory with seeders disabled; avoid reloading shared services.
