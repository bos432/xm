# Acceptance Checklist

## Environment

- Composer installed and `composer install` succeeds in `modernization/backend`.
- `npm install` and `npm run build` succeed in `modernization/frontend`.
- Test database is cloned from production and not writable by the old production site.
- `.env` contains no production secrets in source control.

## Core Workflow

- Admin can log in with a reset password and create/manage baseline configuration.
- Unit user can create a project draft, edit it, upload allowed files, and submit it.
- Unit user cannot access another unit's project or file.
- County, department, expert, and admin reviewer roles only see their assigned tasks.
- Review decisions move the project through submit, review, return, reject, and approve states.
- Returned projects can be edited and resubmitted.

## Security

- Uploading `.php`, `.jsp`, `.asp`, `.phtml`, `.phar`, and disguised script files is rejected.
- Upload paths are not directly web-executable.
- Downloading a file requires authentication and project access.
- Login throttling blocks repeated failed attempts.
- Secret settings are masked in API responses.

## Migration

- `pro_unit`, `pro_pro`, `pro_file`, `pro_review`, and `pro_log` counts are sampled before and after migration.
- Every imported row keeps its old primary key in `legacy_id` or migration metadata.
- Imported attachments exist on disk and have a calculated SHA-256 hash.
- Records with mapping ambiguity are reported and not silently dropped.

## Rollout

- Backup, migration, deployment, smoke test, and rollback are rehearsed in test.
- New projects are created only in the new system after go-live.
- Old system write paths are disabled or access-restricted during parallel operation.
- Daily reconciliation covers project count, review count, attachment count, and error logs.

