# Translations Master Reference

Last updated: 2026-03-07

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
- `docs/CHAT_MASTER_REF.md` for chat-specific localization and deterministic copy rules.

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
  - locale-aware fetch with exact-key lookup and default-locale fallback
  - cache key versioning (`translations:version`) for invalidation after updates
  - English (`en`) system copy is synchronized from `config/locales/en.yml` and treated as code-owned canonical text
  - fallback order in practice:
    1. exact key in requested locale
    2. exact key in default locale (`en`)

## Admin exclusion
- Admin interface copy is intentionally excluded from the translation catalog.
- Excluded prefixes:
  - `admin.*`
  - `toasts.admin.*`
- Rationale:
  - admin is super-admin-only operations tooling
  - copy is fixed English for operational consistency

## Canonical shared copy (Phase 2)
- Introduced `common.actions.*` keys for repeated interface strings to reduce redundant translation work.
- Current canonical shared keys include:
  - `common.actions.create_new`
  - `common.actions.save`
  - `common.actions.save_changes`
  - `common.actions.cancel`
  - `common.actions.confirm`
  - `common.actions.settings`
  - `common.actions.view`
  - `common.actions.open`
  - `common.actions.delete`
  - `common.actions.send`
  - `common.actions.delete_workspace`
  - `common.actions.delete_workspace_label`
  - `common.actions.apply_filters`
  - `common.toasts.workspace_successfully_deleted_title`
- Rule: prefer `common.*` for globally repeated UI labels; keep domain-specific phrasing under local namespaces.
- Duplicate-key policy: repeated strings should be consolidated into `common.*` keys in code; the admin manager should not be used as a long-term surface for duplicate-string cleanup.

## Delivery rule for new copy
For every feature/change before merge:
1. Check whether new UI copy should use an existing `common.*` key.
2. If not, check whether the new phrase appears elsewhere and should become a new `common.*` key.
3. If creating a new common key, update all matching call sites in the same change.
4. Confirm `used_in` metadata links still map to the affected pages.

## Chat deterministic copy rule
- All non-LLM chat copy must be locale-key backed in `app.workspaces.chat.*` or `common.*`.
- This includes:
  - empty-state headings/placeholders/hints
  - confirmation card labels and fixed action labels
  - system/status rows
  - planner fallback text (when no LLM or parsing fallback)
  - executor validation/success/failure responses
  - deterministic structured output labels (for example member list `email/role/status` labels, reusing workspace settings keys where available)
  - client-side validation and fallback request errors in Stimulus controllers
- LLM free-form generated responses are intentionally not key-managed.
- For chat changes, add/update both `en.yml` and `es.yml` in the same PR.

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
  - `type_tag`
  - status (`all`, `fully_translated`, `missing_translations`)
  - auto-apply behavior:
    - select filters submit immediately on change
    - search submits automatically after debounce when query is blank or at least 3 characters
- actions:
  - bulk `Save`
  - `Discard` unsaved edits
  - row-level `Translate missing`
  - row-level revision `History`
- table behavior:
  - full-width within admin content area
  - horizontal scroll
  - fixed minimum widths per column for readability
  - `Save` and `Discard` actions are shown in the top-right header row
  - `Type` is read-only in UI (managed from code)
  - `English` is read-only in UI (source copy control stays in code)
- draft suggestion behavior:
  - `Translate missing` writes a draft suggestion to the form only
  - the row is considered dirty against persisted DB values
  - `Save`/`Discard` activate immediately after a draft is inserted

## Metadata format
`used_in` shape:
```json
[
  { "label": "Account settings page", "path": "/app/account-settings" },
  { "label": "Admin page", "path": "/app/admin/translations" },
  { "label": "Email" }
]
```

Notes:
- Entries can be multiple per key and are rendered comma-separated in one cell.
- If `path` is present and starts with `/`, it is rendered as an internal link.
- Workspace-aware links can use `:workspace_id` placeholders and are resolved at render time to a real workspace id for the current admin user.
- If `path` is omitted (for example `Email` or `Toast`), text is rendered without a link.
- For `common.*` keys, `used_in` is inferred dynamically from view usage.

Tagging guidance:
- `type_tags` examples:
  - `h1`, `h3`, `h4`, `label`, `body`, `button`, `email_subject`, `tab`
- Keys can have multiple tags in both arrays.
- Area tags remain in the data model for backend classification and prompt context, but are no longer exposed in the admin UI table/filter.

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
