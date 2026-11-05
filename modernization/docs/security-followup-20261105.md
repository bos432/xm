# Security Follow-up (2026-11-05)

## Scope

Re-audit the currently published `main` baseline and production public endpoints. No production login, business writes, account changes, database changes, server configuration changes, or shared-service restarts were performed.

## Findings and Fixes

- Frontend `vite@8.0.16` matched current npm advisories (affected through 8.1.5, including one High). Updated the direct range to `^8.3.5`; lockfile resolves `vite@8.3.5` and compatible Rolldown/PostCSS/Lightning CSS updates.
- Composer audit against the current advisory database found 7 advisories affecting 4 packages, including Symfony HttpFoundation, Mime and Routing. A compatible `composer update --with-all-dependencies` resolution stayed on Laravel 12 and upgraded Laravel to 12.71.0 and affected Symfony packages to fixed 7.4 patch versions. The lockfile now passes `composer audit --locked`.
- Source changes are limited to frontend dependency manifests/lockfile and backend lockfile, plus these security/handoff records. No application source behavior was changed in this follow-up.

## Local Verification

- Runtime: Node `v25.2.1`, npm `11.6.2`, PHP `8.3.30`.
- `npm ci --no-audit --no-fund`: exit 0.
- `npm audit --audit-level=moderate`: exit 0, `found 0 vulnerabilities`.
- `npm run lint`: exit 0.
- `npm test`: exit 0, 5 passed, 0 failed.
- `npm run typecheck`: exit 0.
- `npm run build`: exit 0, Vite 8.3.5, 1628 modules transformed.
- `php -d extension=php_zip.dll composer.phar install --no-scripts`: exit 0. The extension was enabled for this process only; `php.ini` was not changed.
- `composer audit --locked`: exit 0, `No security vulnerability advisories found.`
- `php artisan test --compact`: exit 0, 231 tests, 1050 assertions. Windows Laravel console reporter emitted 231 warnings; hosted Linux CI must repeat this exact suite before release.
- `bash modernization/deploy/tests/deploy-release-safety-test.sh`, `deploy-rollback-test.sh`, `queue-worker-watchdog-test.sh`, and `site-backup-test.sh`: all passed.
- `git diff --check`: exit 0.

## Production Read-only Smoke

Executed 2026-11-05 using HTTPS GET only:

```text
200 https://nxm.zlck888.com/
200 https://nxm.zlck888.com/login
200 https://nxm.zlck888.com/api/auth/captcha
200 https://nxm.zlck888.com/api/public/homepage
200 https://nxm.zlck888.com/api/public/application-batches/open
```

The open-batch API body was `[]`. This is a business configuration/readiness concern, not proof of an application defect; no production batch was created or opened. TLS negotiated 1.3; certificate expiry observed as 2027-01-12 18:59:59 local host time.

## Release Gate and Remaining Work

- Candidate `2a354bb` is pushed to `origin/codex/composer-security-fix`. Both hosted workflows passed on that exact revision: Modernization CI run `41951971968` and Modernization Quality Gate run `41951971864`. Backend feature tests, frontend lint/build, deploy safety, and MySQL 5.7 migration compatibility jobs passed. Optional online E2E was skipped to avoid production writes.
- Next, fast-forward this reviewed candidate to remote `main`, then deploy only this site with `RUN_MIGRATIONS=0 RUN_SEED=0`; do not reload shared services. Verify the active release and site-local queue worker.
- Formal readiness remains incomplete until isolated six-role workflow, SMTP delivery, and OSS download/restore rehearsal have current evidence. Do not mutate production business data for those tests.
