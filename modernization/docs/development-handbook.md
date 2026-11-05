# Development Handoff

## Current Status

- Published production baseline: `59bbdec` (`20261018050541`), deployed 2026-10-18 with migrations and Seeder skipped.
- Current isolated follow-up: commit `2a354bb` (security fix `71568ad` plus handoff record) is pushed to `origin/codex/composer-security-fix`. Both hosted workflows passed on 2026-11-05; it is not yet in remote `main` or production.
- Formal operations readiness is not fully verified: six-role isolated E2E, SMTP delivery, and OSS restore rehearsal remain open.

## Recent Increment

2026-11-05, security follow-up: current audits exposed newer Vite and Symfony advisories. Vite frontend fix, Composer lockfile refresh, local regression, read-only public smoke, and hosted CI evidence are recorded in [`security-followup-20261105.md`](security-followup-20261105.md). No production changes were made in this increment.

## Next Step

Fast-forward reviewed candidate `2a354bb` to `main`, then deploy this site with migrations/Seeder disabled; verify its release and queue worker. Do not use the dirty primary workspace for release operations.

## Evidence and State

- Runtime smoke and test outputs: [`security-followup-20261105.md`](security-followup-20261105.md).
- Initial push attempts on 2026-11-05 failed with connection reset/timeout; retry succeeded and pushed through `2a354bb`.
- Hosted runs on the exact `2a354bb` revision: Modernization CI run `41951971968` passed; Modernization Quality Gate run `41951971864` passed. The optional online E2E job was skipped to avoid production writes.
- Production operations history and unresolved readiness gates: [`operations-readiness-verification-20261014.md`](operations-readiness-verification-20261014.md).
- Current worktree is the isolated `codex/composer-security-fix` branch; preserve unrelated dirty changes in the primary worktree.
