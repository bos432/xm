# Legacy Table Map

This map defines the first migration pass from the old `pro_` tables into the Laravel model set.

| Legacy table | New table | Migration priority | Notes |
| --- | --- | --- | --- |
| `pro_unit` | `units` | 1 | Enterprise/unit profile, contacts, region, status, legacy metadata. |
| `pro_manage`, `pro_root` | `users` | 1 | Admin and reviewer accounts. Passwords should be reset, not copied blindly. |
| `pro_pro` | `projects` | 1 | Core project application records and workflow state. |
| `pro_file`, `pro_pdf`, `pro_excel` | `project_files` | 1 | Re-index existing files and validate file existence, extension, size, and owner. |
| `pro_review`, `pro_check_log` | `project_reviews` | 1 | Review stage, decision, score, comments, reviewer, reviewed time. |
| `pro_log` | `operation_logs` | 2 | Historical operation logs, imported after project parity is verified. |
| `pro_message`, `pro_mail`, `pro_sms_log` | notification tables | 2 | Preserve notification history; new outbound delivery should use queues. |
| `pro_config`, `pro_sms_config`, `pro_config_zj` | `system_settings` | 2 | Secrets must be moved to `.env` or a secret manager. |
| `pro_dept`, `pro_city`, `pro_projecttype`, `pro_classfi`, `pro_achieve_type` | lookup tables | 2 | Normalize lookup data after core migration. |
| `pro_cms`, `pro_nav`, `pro_info` | content tables | 3 | Portal content can migrate after application workflow is stable. |

## Migration Rules

- Keep the old database as a read-only source during initial rollout.
- Store old primary keys in `legacy_id` columns for traceability.
- Do not import old passwords into the new system unless the hash format is proven safe and compatible; default to forced password reset.
- Recalculate every imported file's SHA-256 hash and store it in `project_files.sha256`.
- Mark records that cannot be mapped cleanly in `metadata.migration_warning` rather than dropping them silently.

