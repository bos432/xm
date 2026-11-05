# Development Handoff

## Current Status

- Published production baseline: `59bbdec` (`20261018050541`), deployed 2026-10-18 with migrations and Seeder skipped.
- Current isolated follow-up: refreshed Vite and Symfony security fixes on `codex/composer-security-fix`; not yet pushed or deployed.
- Formal operations readiness is not fully verified: six-role isolated E2E, SMTP delivery, and OSS restore rehearsal remain open.

## Recent Increment

2026-11-05, security follow-up: current audits exposed newer Vite and Symfony advisories. Vite frontend fix, Composer lockfile refresh, local regression, and read-only public smoke are recorded in [`security-followup-20261105.md`](security-followup-20261105.md). No production changes were made in this increment.

## Next Step

Review and push the isolated security follow-up commit; wait for the hosted Linux quality workflow and Composer/npm audits to pass. Only then deploy this site with migrations/Seeder disabled, and verify its release and queue worker. Do not use the dirty primary workspace for release operations.

## Evidence and State

- Runtime smoke and test outputs: [`security-followup-20261105.md`](security-followup-20261105.md).
- Production operations history and unresolved readiness gates: [`operations-readiness-verification-20261014.md`](operations-readiness-verification-20261014.md).
- Current worktree is the isolated `codex/composer-security-fix` branch; preserve unrelated dirty changes in the primary worktree.
