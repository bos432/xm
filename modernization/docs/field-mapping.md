# Field-Level Migration Map

This map is the first approved preview pass. It keeps legacy IDs and raw metadata so uncertain fields remain traceable instead of being silently discarded.

## `pro_unit` -> `units` and unit `users`

| Legacy field | New target | Notes |
| --- | --- | --- |
| `id` | `units.legacy_id`, `users.metadata.legacy_unit_id` | Traceability key. |
| `unitname` | `units.name`, `users.name` | Unit display name. |
| `unitcode` | `units.credit_code`, `users.username` fallback | Prefer credit code as stable enterprise identifier. |
| `unitlinker` | `units.contact_name` | Contact person. |
| `unitlinkermobile`, `unittel` | `units.contact_mobile`, `users.mobile` | Mobile preferred, telephone retained in metadata. |
| `linkermail` | `units.email`, `users.email` | Empty strings become null. |
| `unitaddr`, `detailaddr` | `units.address` | Concatenated with a space. |
| `unitaddr` | `units.region_code` | Temporary regional text until normalized region IDs are approved. |
| `state` | `units.status`, `users.is_active` | `通过审核` -> active, others retained in metadata. |
| `password` | `users.metadata.legacy_password_hash` | New accounts require password reset; old hash is not used as a login secret. |
| other fields | `units.metadata.legacy` | Preserved for later normalization. |

## `pro_manage` / `pro_root` -> `users`

| Legacy field | New target | Notes |
| --- | --- | --- |
| `id` | `users.metadata.legacy_manage_id` / `legacy_root_id` | Traceability key. |
| `user_name`, `username` | `users.username` | Admin/reviewer login name. |
| `nick_name`, `username` | `users.name` | Display name. |
| `email`, `phone` | `users.email`, `users.mobile` | Optional. |
| `role` | `users.role` | `0/1/2/3` mapped to admin/county/department/expert as preview only. |
| `state` | `users.is_active` | Disabled only when state clearly indicates inactive. |
| `password` | `users.metadata.legacy_password_hash` | Force reset. |
| other fields | `users.metadata.legacy` | Company, title, bank, ID card retained. |

## `pro_pro` -> `projects`

| Legacy field | New target | Notes |
| --- | --- | --- |
| `id` | `projects.legacy_id` | Traceability key. |
| `claimid` | `projects.unit_id` via unit legacy map | Preview stores `legacy_unit_id`; final import resolves to new unit ID. |
| `proname` | `projects.title` | Project name. |
| `prokind`, `pro_kind` | `projects.project_type`, `projects.category` | Stored as legacy codes until dictionary normalization. |
| `state`, `state_id`, `state_id1` | `projects.status`, `metadata.legacy_state` | Preview status mapping is conservative. |
| `abstract` | `projects.summary` | Project summary. |
| `totalmoney`, `apply_money` | `projects.budget_amount`, `metadata.apply_money` | Budget uses total investment; requested funding retained. |
| `time`, `reccommend_time` | `projects.submitted_at`, metadata | Best-effort date normalization. |
| `region_id`, `check_id`, `experts`, files, comments | `projects.metadata.legacy` | Preserved for workflow/file reconstruction. |

## `pro_file` -> `project_files`

| Legacy field | New target | Notes |
| --- | --- | --- |
| `id` | `project_files.legacy_id` | Traceability key. |
| `pro_id` | `project_files.project_id` via project legacy map | Preview stores `legacy_project_id`. |
| `fname` | `project_files.path` | Actual disk resolution requires file root verification. |
| `name` | `project_files.original_name` | User-facing file name. |
| extension from `fname/name` | `project_files.extension` | Used for script-file blocking checks. |
| `type`, `state_id`, `state_id1`, `pifu` | `metadata.legacy` | Review/acceptance context retained. |

## `pro_review` / `pro_check_log` -> `project_reviews`

| Legacy field | New target | Notes |
| --- | --- | --- |
| `id` | `project_reviews.legacy_id` | Prefix source table in metadata to avoid collisions. |
| `pro_id` / `project_id` | `project_reviews.project_id` via project legacy map | Preview stores `legacy_project_id`. |
| `expert_id`, `user_id` | `reviewer_id` via user legacy map | Preview stores legacy reviewer identifiers. |
| `score` | `project_reviews.score` | Numeric only when parseable. |
| `content`, `comment`, `pifu`, `state` | `comment`, `decision`, metadata | Decision mapping is conservative. |
| `time` | `reviewed_at` | Best-effort date normalization. |

