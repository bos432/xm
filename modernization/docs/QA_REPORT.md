# QA Report - 2026-11-05

## Scope and evidence limits

This increment uses the isolated worktree, SQLite in memory, array mail/cache and synthetic users. Production remains cef21d3. Local API Feature tests do not prove browser usability, MySQL concurrency or production account configuration.

## Defects

QA-10 update: QA08-P1-DETAIL is fixed locally, not deployed. Reviewer drawer and processing view share complete submission sections; three SSR/source-contract tests and county browser detail evidence pass. Processing-dialog/mobile browser verification remains open. Evidence: `qa10-project-details-20261105.json`, `qa10-project-details-green.xml`, screenshot14 under QA-07 run root. QA10-P2-STATUS fixed locally in QA14; six-role API hint regression and draft/returned cases pass, browser still pending.

| ID | Severity | Module | Reproduction command | Actual vs expected | Recommendation/status |
| --- | --- | --- | --- | --- | --- |
| QA17-P1-EXTENSION-OVERWRITE | P1 | Extension decision finality | `php vendor/bin/phpunit tests/Feature/AcceptanceConfigurationAndTimelineTest.php --filter decision_is_final` | Another admin could overwrite approved with rejected200; expected422 and original row unchanged | Fixed locally atomic pending-only update; full240/1376. qa17-extension-finality-20261105.json; true concurrency pending |
| QA16-P1-TERMINAL-EXTENSION | P1 | Acceptance extension | `php vendor/bin/phpunit tests/Feature/AcceptanceConfigurationAndTimelineTest.php --filter terminal` | Completed acceptance allowed new extension201, expected422/no write | Fixed locally; approved/closed/rejected guards, preserved history, browser action hidden. qa16-terminal-extension-20261105.json. Not deployed |
| QA10-P2-STATUS | P2 | Project acceptance next action | `php vendor/bin/phpunit tests/Feature/ProjectAcceptanceHintTest.php` | Submitted unit told to create acceptance; reviewers saw raw status. Expected Chinese state and actual acceptance progress | Fixed locally QA14; green34assertions, backend238/1357, not deployed. qa14-acceptance-hint-20261105.json |
| QA12-P1-DOWNLOAD | P1 | Acceptance materials | Targeted acceptance-errors test red JUnit + county browser acceptance detail | Two PDFs shown without download operation; expected authorized material access | Fixed locally, browser download hash verified; qa12-acceptance-download-20261105.json. Not deployed |
| QA12-P2-TIMELINE | P2 | Acceptance resubmit timeline | AcceptanceConfigurationAndTimelineTest + county browser | Old return appeared as completed current stage | Fixed locally QA13; current-round timeline, full history retained. Not deployed |
| QA12-P2-DATE | P2 | Extension date | AcceptanceConfigurationAndTimelineTest + county browser | Input2026-12-31 became raw UTC timestamp | Fixed locally QA13 date:Y-m-d; browser shows2026-12-31. Not deployed |
| QA13-P1-SCORE | P1 | Acceptance scoring | php vendor/bin/phpunit tests/Feature/AcceptanceConfigurationAndTimelineTest.php | Acceptance ignored system stage score switches | Fixed locally; four-stage disabled422/no state mutation, enabled persistence and hidden-score nulling covered. Not deployed |
| QA-EXPERT-01 | P1 | Expert pending list / CSV | `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php` on pre-fix source | After first assigned expert scores, pending list still contains 1 project; expected 0 for this expert while peer retains task | Fixed locally; pending query excludes this expert's completed review. Not published |
| QA-EXPERT-02 | P1 | Dashboard | Same test with dashboard assertion on pre-fix source | Unassigned expert dashboard says pending=1; task list empty. Expected both zero | Fixed locally; dashboard uses assignment-aware pending count. Not published |
| QA-EXPERT-03 | P1 | Expert return/resubmit | `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php` before QA-05 fix | After expert return and resubmission, prior score hides task and prevents scoring again | Fixed in isolated candidate: latest return ID defines current review round; old history retained, only new scores count. Not deployed |
| QA-GATE-01 | P0 gate | PHP formatting | `php vendor/bin/pint --test` | Exit1, repository-wide line-ending/style violations; expected exit0 | Open. Baseline comparison required; do not mass-reformat unrelated code or call this gate passed |
| QA-GATE-02 | P0 verification gap | PHP coverage | Local `php vendor/bin/phpunit --coverage-text --fail-on-warning`; hosted artifact download API | Local coverage exit1 missing driver; hosted PCOV job passes and artifact exists, numerical report download401 | Open. Read authorized artifact or publish machine-readable CI summary; do not invent coverage/TOP5 |
| QA-DELIVERY-01 | P0 release blocker (resolved transport) | Git transport | `git ls-remote origin refs/heads/codex/composer-security-fix` | Exit1 curl28 connection reset; initial REST branch was cef21d3 | Command-local schannel/HTTP1.1 pushes through ed4f5bf succeeded. Exact candidate CI/Quality gates passed. No production deployment |

## Executed verification

- QA-15 visible browser: department approval -> expert92 -> admin extension approval2026-12-31 -> final approval -> unit completion/extension result observed. Screenshots20..26, two DOM exports in retained QA07 run; `qa15-browser-acceptance-20261105.json`. Local sandbox only, not production. Acceptance currently one assigned expert advances, not group acceptance. New raw decision/time presentation and completed-record extension-action observations pending investigation.

- QA-11 HTTP materials: `node modernization/e2e/verify-isolated-materials.mjs qa07-20261105-browser-fixed`, final exit0; uploads201 (first attempt), owner/county downloads200 with exact SHA256, anonymous401, logout204. First exit1 was test expected200 vs actual204 on logout, retained separately. Evidence qa11-materials-20261105.json; browser filechooser remains unverified, acceptance closure pending. No production changes.

- Red test output: `Failed to assert ... expected 0 ... actual size 1`, 1 test / 9 assertions / 1 failure; full failure metadata: `expert-pending-red-20261105.xml`.
- Dashboard red output: `Failed asserting that 1 is identical to 0`, 1 test / 4 assertions / 1 failure; `expert-dashboard-red-20261105.xml`.
- Green command: `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php --log-junit ../docs/expert-pending-green-20261105.xml`; exit0, `OK (1 test, 30 assertions)`.
- Related regression: `php vendor/bin/phpunit tests/Feature/ExpertPendingTaskLifecycleTest.php tests/Feature/ReviewWorkflowTest.php tests/Feature/ReviewExportTest.php tests/Feature/DashboardSummaryTest.php tests/Feature/ProjectAcceptanceWorkflowTest.php tests/Feature/ProjectApplicationWorkflowTest.php --log-junit ../docs/review-acceptance-regression-20261105.xml`; exit0, `OK (63 tests, 327 assertions)`.
- Full backend: `php vendor/bin/phpunit --log-junit ../docs/backend-regression-20261105.xml`; exit0, `OK (232 tests, 1080 assertions)`.
- Authenticated API lifecycle: `php vendor/bin/phpunit tests/Feature/AuthenticatedProjectLifecycleE2eTest.php --log-junit ../docs/authenticated-lifecycle-green-20261105.xml`; exit0, `OK (1 test, 125 assertions)`. Six roles / eight accounts, real captcha/password login, three independent expert scores, support, mocked local acceptance uploads and staged closure; identity checks, logout204 / revoked tokens401. Laravel kernel integration, not browser E2E. Synthetic test records are ephemeral.
- Expanded full backend with requested coverage: `php vendor/bin/phpunit --coverage-text --fail-on-warning --log-junit ../docs/backend-final-20261105.xml`; exit1, `Tests: 233, Assertions: 1205, PHPUnit Warnings: 1`, `No code coverage driver available`. No test failures; coverage gate failed. New lifecycle test Pint exits0.
- QA-05 supersedes earlier final run: full `php vendor/bin/phpunit --log-junit ../docs/backend-final-20261105.xml` exit0, `OK (234 tests, 1243 assertions)`. Coverage rerun to `backend-coverage-final-20261105.xml` exits1, same test/assertion counts, missing-driver warning.
- Expanded authenticated branches: `authenticated-branches-20261105.xml`, exit0, 1 test141 assertions; county return/edit/resubmit, missing materials422, admin extension handling, owner visibility and county403. Targeted resubmission plus full lifecycle: `expert-resubmission-green-20261105.xml`, exit0, 3 tests193 assertions. Red resubmission failure retained in expert-resubmission-red XML.
- Git synchronization supersedes initial transport blocker: candidate5842395 pushed exit0; exact-revision hosted CI41963835843 and Quality41963836006 completed/success. Online E2E intentionally skipped; MySQL check only migrates, so business/concurrency evidence remains missing. No deployment.
- QA-06 supersedes migration-only MySQL evidence: candidateed4f5bf CI41964436275 and Quality41964436249 completed/success. Five business regression files execute on isolated MySQL5.7 with explicit driver assertion. MySQL JUnit artifact13387185885; PCOV Clover/JUnit artifact13386214189. Public download401/logs403; numerical contents not yet inspected. True concurrency remains unverified. `qa06-hosted-evidence-20261105.json` contains authoritative job/artifact IDs.
- Frontend commands: `npm run lint`, `npm test`, `npm run typecheck`, `npm run build`; all exit0. Unit output: tests5/pass5/fail0. Build output: Vite8.3.5, 1628 modules transformed. Utility typecheck does not cover every Vue component.
- Negative authorization: outside-assignment expert score POST403, repeated expert score422; included in green test.

## Not verified

QA-08 browser update: seven accounts across five roles exercised real login/UI submission -> county -> department -> three independent experts -> admin approval. Evidence `qa08-browser-20261105.json` and nine screenshots in `e2e/reports/runs/qa07-20261105-browser-fixed/screenshots`. Acceptance/super-admin browser and actual attachments remain incomplete; prior blanket browser not_run below is superseded only for this verified path.

QA-09: unit acceptance creation/submission and county return exercised in actual browser. Empty files accepted only with no required-material policy. After setting isolated batch requirements, backend rejects missing materials but original UI showed no error; console evidence confirms exception. Locally fixed AcceptanceView action catches; six failure/retry regression tests green, frontend11/11 plus lint/typecheck/build pass. Browser now visibly shows missing-material error. `qa09-acceptance-feedback-20261105.json`, red/list-red/green JUnit and screenshot13 retain proof. No production deployment. IAB filechooser timed out twice; upload/closure remain unverified.

| ID | Severity | Module | Reproduction | Actual vs expected | Recommendation |
| --- | --- | --- | --- | --- | --- |
| QA08-P1-DETAIL | P1 | Review project details | Local UI create project with leader/contact -> submit -> county/department/expert details; `php modernization/e2e/inspect-isolated.php` with isolated sandbox env, exit0 | Saved leader/contact present in SQLite but omitted from review details/processing; reviewers need full submission | Reuse a complete shared read-only project submission component; verify metadata/attachments across reviewer roles |
| QA09-P1-ERROR-FEEDBACK | P1 | Acceptance actions | In returned acceptance with required materials, click Submit without uploads; `node --test tests/acceptance-errors.test.js` red5/5 -> green6/6 | Original backend rejection only in console; now Chinese error toast, form preserved and retry available | Fixed locally across action/list/detail handlers; production release pending |

Database output evidence: `post-final-review.json`, driver sqlite/status approved/budget125000.00, expert scores90/88/94 and support total6.5wan. This is local synthetic data, not production E2E. Fixture correction (E2E- batch intentionally hidden) is a harness issue, not a product defect.

- Production account-specific cause of expert empty tasks: no current account/assignment snapshot inspected this increment.
- Full six-role browser workflow, return/resubmit, extension and acceptance closure with actual login: not_run. Existing Feature tests alone are not equivalent.
- MySQL functional business regression now passed in isolated CI; true concurrent writes and resource soak remain not_run. Test named concurrent in existing suite exercises sequential repeat requests only. Hosted coverage artifact unread due401; local coverage gate still fails.
- SMTP real delivery, OSS download/isolated restore, complete handover screenshots: incomplete.
- Pint comparison: six touched baseline PHP files extracted from cef21d3 with git archive also fail Pint; command/result metadata in qa05-evidence JSON. This demonstrates baseline style debt in these files, not a passing formatting gate.
- Test-authoring failures retained in authenticated-lifecycle-red / attempt2 XML: incorrect account count and me JSON path, corrected to observed API contract. Attempt3 passed75 assertions before added identity/revocation checks. These are test defects, not product findings.

## Coverage and high-risk targets

Line/branch coverage: unavailable, not 0% and not 100%. A ranked uncovered-file TOP5 cannot be honestly computed without coverage evidence. Risk-based targets (not measured ranking): ReviewController.php, ReviewDispatchMatcher.php, AcceptanceController.php, ProjectController.php, DashboardController.php.
