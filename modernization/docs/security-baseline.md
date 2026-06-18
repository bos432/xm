# Security Baseline

## Production Exposure

- Only expose the Laravel `public` directory in the new system.
- Do not expose the old site root as a writable web root after the new system starts accepting applications.
- Deny script execution in legacy upload/static paths: `upload`, `uploads`, `img`, `images`, `js`, `css`, `excel`, `ueditor/php/upload`, and editor demo directories.
- Remove or quarantine `.infected`, demo upload handlers, cross-language examples, and backup archives from web-accessible paths.
- Use `scripts/New-LegacySecurityPublicExecutableWorklist.ps1` to turn executable public/upload findings into JSON, CSV, and Markdown operator worklists before sign-off.

## Upload Controls

- Allowed extensions: `jpg`, `jpeg`, `png`, `pdf`, `doc`, `docx`, `xls`, `xlsx`, `zip`.
- Block executable or ambiguous extensions: `php`, `phtml`, `phar`, `jsp`, `asp`, `aspx`, `exe`, `sh`, `bat`, `cmd`.
- Limit uploads to `UPLOAD_MAX_KB`, default `20480` KB.
- Store files outside public web paths and serve downloads through authenticated API endpoints.
- Save original name, MIME type, extension, size, hash, uploader, project, and purpose.

## Identity And Access

- Use Laravel Sanctum for API authentication.
- Apply login throttling and disable inactive accounts.
- Unit users can only access their own unit's projects and files.
- Reviewers can only act on projects assigned to their current workflow stage.
- Admin configuration pages must mask secret values.

## Legacy Read-Only Boundary

- Keep old ThinkPHP available only for historical lookup during parallel operation.
- Restrict old admin routes by IP and strong credentials.
- Disable old upload, edit, and write endpoints where business allows.
- Review scan output from `scripts/Scan-LegacyRisk.ps1` before every rollout rehearsal.
