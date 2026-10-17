# Dependency Security Upgrade (2026-10-18)

## Scope and Release Status

This is a candidate change on the isolated `codex/composer-security-fix` branch. It has passed the hosted quality gate recorded for the exact candidate commit, but it has not been merged or deployed. Production remains on its existing release pending a staged release check and site-local deployment approval.

## Changes

- Upgrade Laravel from 11.x to 12.70.0. The audited Laravel advisories include affected Laravel 11 versions; the fixed lines require Laravel 12.60.0 or later.
- Upgrade PHPUnit from 11.2.6 to 11.5.57, beyond the 11.5.50 advisory fix.
- Upgrade compatible development dependencies, including Collision 8.9.5.
- Relax the direct Symfony Console constraint from `7.3.*` to `^7.3`; Laravel 12 resolves Symfony Console 7.4.21.
- Pin transitive `postcss-selector-parser` to 7.1.6 using npm overrides, retaining ESLint plugin Vue 9 rather than taking an unnecessary major upgrade.
- Add the `Modernization Quality Gate` GitHub Actions workflow for PHP tests/audit, frontend audit/lint/tests/typecheck/build, migration SQL dry-run, route registration and isolated deploy rollback tests.

## Local Verification

In the isolated worktree:

- PHP 8.3.30, PHPUnit 11.5.57: `vendor/bin/phpunit --no-coverage` -> **231 tests, 1050 assertions, OK**.
- PHP syntax: 88 application PHP files -> **PASS**.
- Composer audit -> **No security vulnerability advisories found**.
- npm audit -> **found 0 vulnerabilities**.
- Frontend lint, 5 Node tests, utility typecheck and production build -> **PASS**.
- Migration SQL dry-run against in-memory SQLite and API route registration -> **PASS in GitHub Actions**.
- `bash modernization/deploy/tests/deploy-rollback-test.sh` -> **Deployment isolation and rollback checks passed**.
- `git diff --check` -> **PASS**.
- GitHub Actions previously recorded for the final candidate (`ac2b358c95afca6242b91186ff9c5f20a61db560`): `39054876588` and `39054876526`, both completed successfully. The optional online E2E job was skipped. This run was not independently re-queried in this turn because GitHub CLI is unauthenticated.
- Production read-only role smoke on 2026-10-18: six dedicated roles logged in, read `/api/auth/me` and project/review/acceptance endpoints, then logged out. No business writes were made.

## Known Verification Caveats

- Windows `php artisan test` presents 231 `file_get_contents` warnings from its console reporter even though the same PHPUnit suite is clean. GitHub's Ubuntu feature-test job completed successfully.
- Full Pint check on this Windows checkout reports pre-existing repository-wide line-ending/style differences. Format-only churn is not included in this security change and Pint is not used as a release gate here.
- The in-memory migration dry-run does not apply migrations to production or prove production schema parity.
- No production database, credentials, queue worker, mail provider, OSS bucket, or business records were changed by the candidate build. Six-role production login/GET probes were run as a separate read-only smoke check.

## Release Gate

Do not deploy until an isolated staging restore verifies dependency compatibility and the release candidate. If that gate passes, create a site-local archive, verify the deployment script and release target, and deploy only `nxm.zlck888.com` with `RUN_MIGRATIONS=0 RUN_SEED=0`. Verify public/API/health checks, then identify the queue worker by its `/proc/<pid>/cwd` resolving inside this site's active release and send TERM only to that PID; the site's watchdog should relaunch it from the new `current` release. The watchdog must resolve `current/backend` before every worker invocation, not once at startup. Confirm the new PID is `www`, its cwd is the new release, `queue:failed` remains zero, and the watchdog is singular. Do not use the framework-wide `queue:restart` cache signal, or restart Supervisor, Nginx, MySQL, PHP-FPM, or the server. Keep the previous release for immediate site-only rollback. Before declaring full operations readiness, still stage and verify real project/acceptance workflows, SMTP delivery, OSS download/restore, and load/recovery expectations.
