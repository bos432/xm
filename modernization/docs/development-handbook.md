# Development Handoff

## Current Status

- Published production baseline: `59bbdec` (`20261018050541`), deployed 2026-10-18 with migrations and Seeder skipped.
- Current isolated follow-up: commit `71568ad` refreshes Vite and Symfony security fixes on `codex/composer-security-fix`; local verification passed, but GitHub push failed because outbound HTTPS connections to port 443 were reset/timed out. It is not in remote `main` and is not deployed.
- Formal operations readiness is not fully verified: six-role isolated E2E, SMTP delivery, and OSS restore rehearsal remain open.

## Recent Increment

2026-11-05, security follow-up: current audits exposed newer Vite and Symfony advisories. Vite frontend fix, Composer lockfile refresh, local regression, and read-only public smoke are recorded in [`security-followup-20261105.md`](security-followup-20261105.md). No production changes were made in this increment.

## Next Step

Retry pushing `71568ad` to `origin/codex/composer-security-fix` when GitHub HTTPS is reachable; wait for the hosted Linux quality workflow to pass. Only then fast-forward reviewed changes to `main` and deploy this site with migrations/Seeder disabled; verify its release and queue worker. Do not use the dirty primary workspace for release operations.

## Evidence and State

- Runtime smoke and test outputs: [`security-followup-20261105.md`](security-followup-20261105.md).
- Push attempts on 2026-11-05: `git push origin codex/composer-security-fix` failed with `Recv failure: Connection was reset`; retry with Schannel/HTTP 1.1 failed to connect to `github.com:443` within 21 seconds. Candidate commit remains local at `71568ad`.
- Production operations history and unresolved readiness gates: [`operations-readiness-verification-20261014.md`](operations-readiness-verification-20261014.md).
- Current worktree is the isolated `codex/composer-security-fix` branch; preserve unrelated dirty changes in the primary worktree.
