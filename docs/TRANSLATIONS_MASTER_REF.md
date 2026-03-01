# Translations Master Reference

Last updated: 2026-03-01

## Service and goal
- Service: database-backed internationalization for the signed-in and email experiences.
- Why we use it: manage translations internally with auditability, filtering, and controlled LLM-assisted generation.
- Outcome we need: reliable runtime translation lookup with safe fallback behavior.

## Purpose
Single source of truth for locale behavior, translation architecture, schema, admin tooling, and translation quality rules.

Related references:
- `docs/ADMIN_MASTER_REF.md` for admin namespace access control and bootstrap behavior.
- `docs/ACCOUNT_SETTINGS_MASTER_REF.md` for user locale preference updates.
- `docs/EMAILS_MASTER_REF.md` for recipient-locale mailer behavior.
- `docs/ENV_VARS.md` for translation/admin environment variables.

## V1 locale scope
- Supported locales: `en`, `es`
- Default locale: `en`
- Missing keys in CI are currently allowed.

## Locale resolution behavior
Precedence order:
1. `current_user.preferred_locale` (if present and supported)
2. `session[:locale]` (if present and supported)
3. Browser `Accept-Language` first value:
   - `es*` -> `es`
   - all others -> `en`
4. fallback `en`

Persistence behavior:
- Session locale is updated on each request.
- For signed-in users with blank `preferred_locale`, detected locale is persisted once.
- Account settings supports explicit language preference updates.

## Runtime architecture
- I18n backend chain:
  1. DB backend: `Translations::DatabaseBackend`
  2. YAML backend fallback: standard Rails locale files
- Runtime lookup service:
  - `Translations::RuntimeLookupService`
  - locale-aware fetch with default-locale fallback
  - cache key versioning (`translations:version`) for invalidation after updates

## Data model
- `translation_keys`
  - `key` (unique)
  - `notes`
  - `area_tags:text[]`
  - `type_tags:text[]`
  - `used_in:jsonb` (array of `{label, path}`)
  - `content_scope` (`system` by default)
- `translation_values`
  - FK `translation_key_id`
  - `locale` (`en`/`es`)
  - `value`
  - `source` (`seed`/`manual`/`llm`)
  - `updated_by_id`
  - unique `(translation_key_id, locale)`
- `translation_value_revisions`
  - FK `translation_value_id`
  - `locale`
  - `old_value`
  - `new_value`
  - `changed_by_id`
  - `change_source`
  - timestamps

## Admin manager (`/app/admin/translations`)
Main capabilities:
- table editor with `English`, `Used in`, and `Spanish` columns
- filters:
  - search (`q`)
  - `area_tag`
  - `type_tag`
  - `missing_only`
- actions:
  - bulk `Save`
  - `Discard` unsaved edits
  - row-level `Translate missing`
  - row-level revision `History`

## Metadata format
`used_in` shape:
```json
[
  { "label": "Account settings page", "path": "/app/account-settings" },
  { "label": "Workspace settings team tab", "path": "/app/workspaces/:id/workspace-settings?tab=team" }
]
```

Tagging guidance:
- `area_tags` examples:
  - `authentication`, `workspace_settings`, `toasts`, `emails`, `navigation`
- `type_tags` examples:
  - `h1`, `label`, `body`, `button`, `toast_title`, `toast_body`, `email_subject`
- Keys can have multiple tags in both arrays.

## LLM generation rules
- Service: `Translations::OpenaiTranslationService`
- Trigger: row action `Translate missing`
- Constraints:
  - fill only missing locale cells
  - never overwrite existing translated values
  - preserve interpolation placeholders exactly (`%{...}`)
  - reject malformed output where placeholder parity fails
- Generated values are staged as draft suggestions and require explicit save.

## Revision and audit behavior
- Every persisted value change creates `translation_value_revisions` entry.
- History endpoint returns most recent revisions for a key.
- Change records include:
  - locale
  - old/new value
  - change source
  - actor
  - timestamp

## Email locale behavior
- Mailers resolve locale from recipient preference when available.
- Unknown/blank locale falls back to `en`.
- Existing email trigger behavior remains unchanged; only rendering locale selection is new.

## Exclusion boundary (non-goal in V1)
- User-generated content is excluded from translation catalog ingestion and runtime management.
- Examples: workspace names, query names, free-text user content.
- `content_scope` exists for future expansion but V1 manages system copy only.

## Environment variables
- `SUPER_ADMIN_BOOTSTRAP_EMAILS`
- `OPENAI_API_KEY`
- `OPENAI_TRANSLATIONS_MODEL`
