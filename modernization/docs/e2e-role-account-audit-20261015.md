# E2E Role Account Audit (2026-10-15)

## Scope

Read-only production account-list inspection and local test-harness correction. No passwords, password hashes, tokens, SMTP secrets, or OSS credentials were read. No production accounts, settings, business data, or services were changed.

## Production account role evidence

The signed-in super-admin account list showed these enabled role assignments:

| Account | Actual role | E2E use |
| --- | --- | --- |
| `e2e_20260630_103223_unit` | `unit` | Unit |
| `e2e_20260630_103223_county` | `county` | County reviewer |
| `e2e_20260630_103223_department` | `department` | Department reviewer |
| `e2e_20260630_103223_expert` | `expert` | Expert reviewer |
| `e2e_20260630_103223_admin` | `super_admin` | Super-admin only; do not bind to `E2E_ADMIN_*` |
| `e2e_20260702_delivery_admin` | `admin` | Business-admin candidate |

The `e2e_20260702_delivery_admin` account was verified by the admin UI to have role `业务管理员` and active status. Its password was not inspected or tested.

## Harness correction

Commit `cf50fa2` on `codex/oss-backup-runtime-safety` adds an explicit E2E role-to-credential map and verifies the authenticated `/api/auth/me` role after browser login. The CI test-list check separately requires the `admin` and `super_admin` cases. This prevents a super-admin credential accidentally assigned to the business-admin slot from being counted as a successful role test.

The protected CI job requires all role usernames/passwords through GitHub Actions secrets. Do not place credentials in this repository or chat. Set `E2E_ADMIN_USERNAME` to a dedicated account whose verified role is `admin`, and `E2E_SUPER_ADMIN_USERNAME` to a separate `super_admin` account. Use unique, rotated test passwords through the repository's secret manager.

## Verification

- Frontend lint: passed.
- Frontend tests: 5 passed, including distinct `admin`/`super_admin` role mapping.
- Frontend typecheck and production build: passed.
- E2E discovery: 10 tests listed, including distinct admin and super-admin cases.
- Backend: 200 passed (914 assertions).
- Production login attempts: not performed because test passwords were unavailable.
- Full six-role online browser flow: not verified by this audit.
