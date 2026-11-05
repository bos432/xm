# Development Handoff

## Current Status

- Published production baseline: `cef21d38e6989cffc9cc5e516dbd14f4a445d6c5` (`20261105105750`), deployed 2026-11-05 with migrations and Seeder skipped. Previous rollback target: `20261018050541` / `59bbdec`.
- Remote `main` and production match `cef21d3`; exact-revision hosted gates passed. Independent HTTPS login/logout, seven HTTP paths, and one site PHP worker on the new release verified. Anonymous browser E2E: 2 passed.
- Formal operations readiness is not fully verified: six-role isolated E2E, SMTP delivery, and OSS restore rehearsal remain open.

## Recent Increment

2026-11-05, QA-01 E2E runner repair: fixed Windows shell interpretation of test arguments; original failing command now passes both public tests. Production remains successfully deployed `cef21d3`. Evidence: [`release-verification-20261105.json`](release-verification-20261105.json) and [`production-release-20261105.md`](production-release-20261105.md).

## Next Step

Prepare isolated six-role business E2E with a separate database/storage and disabled external delivery; validate project submission, expert assignment/scoring and acceptance without production business writes. First inspect available local runtime and existing fixtures; preserve not_run for unavailable external evidence.

## Evidence and State

- Runtime smoke and test outputs: [`security-followup-20261105.md`](security-followup-20261105.md).
- Initial push attempts on 2026-11-05 failed with connection reset/timeout; retry succeeded and pushed through `2a354bb`.
- Hosted runs on the exact `2a354bb` revision: Modernization CI run `41951971968` passed; Modernization Quality Gate run `41951971864` passed. The optional online E2E job was skipped to avoid production writes.
- Production operations history and unresolved readiness gates: [`operations-readiness-verification-20261014.md`](operations-readiness-verification-20261014.md).
- Current worktree is the isolated `codex/composer-security-fix` branch; preserve unrelated dirty changes in the primary worktree.

## 2026-11-05 OPS-01: Production Preflight

- Scope: verify remote candidate, exact-revision hosted gates and current production state. Deployment and business E2E remain incomplete.
- Files: this handbook and `release-verification-20261105.json`; no application source changes.
- Commands: `git ls-remote origin refs/heads/main` returned `cef21d3`, exit 0. GitHub public API returned completed/success for runs 41952385666 and 41952385683 on that exact SHA. `gh run view` could not authenticate (exit 1); public API supplied equivalent evidence without changing credentials.
- Cloud invocation `t-hk0725kk8pqws1s`: exit 128 at Git ownership check. No global safe.directory exception was added. Corrected invocation `t-hk0725kr7x2stts` used `runuser -u www -- git ... rev-parse HEAD`, exit 0. Full command is preserved in the Cloud Assistant invocation.
- Production: release `20261018050541`, commit `59bbdecad2295834cbd6fc27b57ac409778b253c`; PHP 8.3.36, Node 20.19.2, npm 10.8.2; disk 71 percent used / 83 GB available; queue failed count 0; public captcha HTTP 200.
- Permissions and data: commands are read-only and site scoped. No account, tenant, application, database, mail, OSS or business-state writes. Production release unchanged; no shared service restart. Role isolation and error branches are not_run in this increment. Acceptance ledger unchanged.
- Next: deploy candidate with RUN_MIGRATIONS=0 and RUN_SEED=0, then record active commit and queue process evidence.

## 2026-11-05 OPS-02: Failed Release and Cache Recovery

- Scope: attempted fixed-candidate release, preserved health gate and verified automatic rollback. Full release remains incomplete.
- Evidence: `release-verification-20261105.json`; Cloud Assistant invocations `t-hk0725lpfjtyhvk` (deploy exit 1), `t-hk0725mf05s991c` (diagnosis exit 0), `t-hk0725mvkjzi800` (recovery exit 0).
- Deploy command used RUN_MIGRATIONS=0 RUN_SEED=0 and nice/ionice; frontend Vite 8.3.5 and Composer install completed, then `health:login-check` failed. Script restored previous current link. The external umask 077 caused root-owned 600/700 shared cache files; this was an operator invocation error, not established as a dependency regression.
- Recovery commands: chown www:www and chmod 640 on this site's shared bootstrap-cache PHP files only; as www, `php artisan config:cache`, `route:cache`, and `health:login-check`. Exit 0; output confirms HTTP login passed and token revoked. Cache permissions verified 640 www:www.
- Production changes: transient site release switch followed by automatic rollback; this site's cache files regenerated for old release. No migration, Seeder, formal business writes, global settings, or shared service restart. Health login creates/revokes only the dedicated probe token. Role/tenant E2E not_run; acceptance ledger unchanged.
- Next: retry under group www with umask 027, preserving the same reviewed candidate and health checks; inspect actual candidate login result before acceptance.

## 2026-11-05 OPS-03: Production Release and Independent Verification

- Scope: deploy reviewed dependency security candidate and verify HTTP/login/queue; anonymous browser tests. Six-role business workflow, SMTP delivery and OSS restore still incomplete.
- Files: this handbook, `release-verification-20261105.json`, `production-release-20261105.md`; browser JSON/HTML/screenshots in `modernization/e2e/reports/runs/20261105-postrelease-public/` (ignored generated evidence, retained locally).
- Cloud deployment `t-hk0725n6ge53lds`: exit 0, release `20261105105750`, commit `cef21d3`. Invocation uses `sg www`, umask 027, nice 15, idle I/O; no migrations or Seeder. Afterwards site shared cache normalized to 640 www:www.
- Independent invocation `t-hk0725nrafxzmyo`: exit 0; HTTPS health login and logout passed, probe token revoked; `queue:restart` gracefully restarts site queue, failed jobs 0; seven site HTTP paths returned 200. Worker verification `t-hk0725o8k0ewikg`: exit 0; one PHP worker PID 2136790 and flock wrapper PID 2136789, both on the new backend directory. Wrapper is not a duplicate PHP worker.
- Browser command: with process-only NODE_PATH=frontend/node_modules and E2E_RUN_ID=20261105-postrelease-public, `node node_modules/@playwright/test/cli.js test --config ../e2e/playwright.config.js --grep 'public homepage|public and anonymous'`, exit 0, 2 passed in 5.7 seconds. Node warning: NO_COLOR ignored due to FORCE_COLOR. Initial npm wrapper invocation failed because shell interpreted the regex pipe; direct CLI initially lacked NODE_PATH; both tooling failures preserved in the release report, then resolved by invocation only.
- Isolation/error evidence: anonymous protected APIs return JSON 401 and sensitive public paths return 404 in these tests. No role-login/business writes, no application account changes, no DB migration/Seeder, no external email or OSS writes. Only dedicated health login token/log effects and site cache/queue restart. No shared service reload. Acceptance ledger unchanged.
- Next: isolated six-role browser workflow and expert-task diagnosis; retain SMTP and OSS restore as incomplete until stronger evidence exists.

## 2026-11-05 QA-01: E2E Runner Argument Safety

- Scope: fix confirmed Windows shell interpretation of grep regex pipe. No application business/source behavior changes; isolated six-role E2E remains pending.
- Changed: `modernization/frontend/scripts/run-e2e.mjs` now spawns process.execPath with Playwright CLI and argument array; removes shell invocation. Evidence metadata and release report updated; generated JSON evidence is `modernization/e2e/reports/runs/20261105-postrelease-wrapper/results.json`.
- Red: original `npm run e2e -- --grep 'public homepage|public and anonymous'` exited 1 with `'public' is not recognized`. Green: exact original command with E2E_RUN_ID=20261105-postrelease-wrapper, exit 0, two public tests passed in 4.4s. No dependency changes. `node --check modernization/frontend/scripts/run-e2e.mjs` and `git diff --check` exit 0. Local Node v25.2.1 / npm 11.6.2.
- Permissions/data/errors: anonymous 401 and sensitive-path 404 verified; role-auth flows not_run. No server configuration, production release, DB, business data, email or OSS modifications in this increment. Acceptance ledger unchanged. Production remains cef21d3 and new test-tool changes remain isolated pending Git integration.
- Next: inspect local runtime and fixtures for isolated six-role workflow; then run lifecycle/score/acceptance browser verification without production business writes.
