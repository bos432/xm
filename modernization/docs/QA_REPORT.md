# QA Report - 2026-11-05

## Scope and evidence limits

This increment uses the isolated worktree, SQLite in memory, array mail/cache and synthetic users. Production remains cef21d3. Local API Feature tests do not prove browser usability, MySQL concurrency or production account configuration.

## Defects

| ID | Severity | Module | Reproduction command | Actual vs expected | Recommendation/status |
| --- | --- | --- | --- | --- | --- |
| QA-EXPERT-01 | P1 | Expert pending list / CSV | `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php` on pre-fix source | After first assigned expert scores, pending list still contains 1 project; expected 0 for this expert while peer retains task | Fixed locally; pending query excludes this expert's completed review. Not published |
| QA-EXPERT-02 | P1 | Dashboard | Same test with dashboard assertion on pre-fix source | Unassigned expert dashboard says pending=1; task list empty. Expected both zero | Fixed locally; dashboard uses assignment-aware pending count. Not published |
| QA-EXPERT-03 | P1 | Expert return/resubmit | `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php` before QA-05 fix | After expert return and resubmission, prior score hides task and prevents scoring again | Fixed in isolated candidate: latest return ID defines current review round; old history retained, only new scores count. Not deployed |
| QA-GATE-01 | P0 gate | PHP formatting | `php vendor/bin/pint --test` | Exit1, repository-wide line-ending/style violations; expected exit0 | Open. Baseline comparison required; do not mass-reformat unrelated code or call this gate passed |
| QA-GATE-02 | P0 verification gap | PHP coverage | Local runtime `php -m` lists neither PCOV nor Xdebug | Cannot measure local line coverage or TOP5 uncovered files | Open. Obtain isolated coverage runtime/hosted exact-revision report |
| QA-DELIVERY-01 | P0 release blocker | Git transport | `git ls-remote origin refs/heads/codex/composer-security-fix` | Exit1 curl28 connection reset; initial REST branch was cef21d3 | Transport recovered: command-local schannel/HTTP1.1 push exit0 through0ea4c1a. Final QA-05 synchronization and hosted gates pending |

## Executed verification

- Red test output: `Failed to assert ... expected 0 ... actual size 1`, 1 test / 9 assertions / 1 failure; full failure metadata: `expert-pending-red-20261105.xml`.
- Dashboard red output: `Failed asserting that 1 is identical to 0`, 1 test / 4 assertions / 1 failure; `expert-dashboard-red-20261105.xml`.
- Green command: `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php --log-junit ../docs/expert-pending-green-20261105.xml`; exit0, `OK (1 test, 30 assertions)`.
- Related regression: `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php tests/Feature/ReviewWorkflowTest.php tests/Feature/ReviewExportTest.php tests/Feature/DashboardSummaryTest.php tests/Feature/ProjectAcceptanceWorkflowTest.php tests/Feature/ProjectApplicationWorkflowTest.php --log-junit ../docs/review-acceptance-regression-20261105.xml`; exit0, `OK (63 tests, 327 assertions)`.
- Full backend: `php vendor/bin/phpunit --log-junit ../docs/backend-regression-20261105.xml`; exit0, `OK (232 tests, 1080 assertions)`.
- Authenticated API lifecycle: `php vendor/bin/phpunit tests/Feature/AuthenticatedProjectLifecycleE2eTest.php --log-junit ../docs/authenticated-lifecycle-green-20261105.xml`; exit0, `OK (1 test, 125 assertions)`. Six roles / eight accounts, real captcha/password login, three independent expert scores, support, mocked local acceptance uploads and staged closure; identity checks, logout204 / revoked tokens401. Laravel kernel integration, not browser E2E. Synthetic test records are ephemeral.
- Expanded full backend with requested coverage: `php vendor/bin/phpunit --coverage-text --fail-on-warning --log-junit ../docs/backend-final-20261105.xml`; exit1, `Tests: 233, Assertions: 1205, PHPUnit Warnings: 1`, `No code coverage driver available`. No test failures; coverage gate failed. New lifecycle test Pint exits0.
- QA-05 supersedes earlier final run: full `php vendor/bin/phpunit --log-junit ../docs/backend-final-20261105.xml` exit0, `OK (234 tests, 1243 assertions)`. Coverage rerun to `backend-coverage-final-20261105.xml` exits1, same test/assertion counts, missing-driver warning.
- Expanded authenticated branches: `authenticated-branches-20261105.xml`, exit0, 1 test141 assertions; county return/edit/resubmit, missing materials422, admin extension handling, owner visibility and county403. Targeted resubmission plus full lifecycle: `expert-resubmission-green-20261105.xml`, exit0, 3 tests193 assertions. Red resubmission failure retained in expert-resubmission-red XML.
- Frontend commands: `npm run lint`, `npm test`, `npm run typecheck`, `npm run build`; all exit0. Unit output: tests5/pass5/fail0. Build output: Vite8.3.5, 1628 modules transformed. Utility typecheck does not cover every Vue component.
- Negative authorization: outside-assignment expert score POST403, repeated expert score422; included in green test.

## Not verified

- Production account-specific cause of expert empty tasks: no current account/assignment snapshot inspected this increment.
- Full six-role browser workflow, return/resubmit, extension and acceptance closure with actual login: not_run. Existing Feature tests alone are not equivalent.
- True concurrent MySQL writes, resource soak, and full code coverage: not_run. Test named concurrent in existing suite exercises sequential repeat requests only.
- SMTP real delivery, OSS download/isolated restore, complete handover screenshots: incomplete.
- Pint comparison: six touched baseline PHP files extracted from cef21d3 with git archive also fail Pint; command/result metadata in qa05-evidence JSON. This demonstrates baseline style debt in these files, not a passing formatting gate.
- Test-authoring failures retained in authenticated-lifecycle-red / attempt2 XML: incorrect account count and me JSON path, corrected to observed API contract. Attempt3 passed75 assertions before added identity/revocation checks. These are test defects, not product findings.

## Coverage and high-risk targets

Line/branch coverage: unavailable, not 0% and not 100%. A ranked uncovered-file TOP5 cannot be honestly computed without coverage evidence. Risk-based targets (not measured ranking): ReviewController.php, ReviewDispatchMatcher.php, AcceptanceController.php, ProjectController.php, DashboardController.php.
