# UI Preferences Master Reference

Last updated: 2026-04-02

## Purpose
Single source of truth for user-scoped UI preference persistence in sqlbook.

This document exists to keep small personalization features out of browser-only storage and to avoid ad hoc preference columns or one-off storage rules per surface.

Related references:
- `docs/QUERIES_MASTER_REF.md`
- `docs/ACCOUNT_SETTINGS_MASTER_REF.md`
- `docs/PROJECT_CONTEXT.md`

## Scope
- UI preferences are user-scoped, not workspace-scoped.
- UI preferences store presentation choices and lightweight personalization only.
- UI preferences must not be used for permissions, feature flags, billing state, or domain records.
- UI preferences must not become a dumping ground for large or opaque blobs.

## Persistence model
- Canonical storage is `users.ui_preferences`.
- `ui_preferences` is a server-owned `jsonb` column on `users`.
- Preferences are persisted in the database, not in local storage or cookies, unless a feature is explicitly designed as browser-only and documented as such.
- Preference keys must be namespaced by surface to avoid collisions.

## Current namespaces
- `query_library.visible_columns`
  - Array of query-library table column keys that the current user has chosen to keep visible.
  - If missing or empty, the app falls back to the default visible-column set defined by the server.

## Rules for adding new preferences
- Prefer adding a new namespaced key under `ui_preferences` when:
  - the setting is user-specific
  - the setting is low-risk presentation state
  - the value is small and easy to validate
- Do not add a new top-level database column for every small UI toggle.
- Do not persist UI-only preferences in the browser when the same user is expected to see the same preference across devices or sessions.
- Each new preference should define:
  - owner surface
  - key path
  - allowed values
  - default fallback behavior when the key is absent or invalid

## Validation and defaults
- The app should always sanitize persisted preference values before using them.
- Unknown, removed, or invalid values must fall back to a safe default rather than raising.
- Server-side defaults are authoritative.

## Current query-library behavior
- Query Library exposes a columns dropdown beside search.
- By default, all supported columns are visible.
- If the user changes column visibility, the app persists the selection to `users.ui_preferences.query_library.visible_columns`.
- The preference follows the user across sessions and devices because it is server-persisted.

## Implementation guidance
- Keep reads/writes behind model methods or a small service boundary instead of scattering raw `ui_preferences` mutation across controllers and views.
- New UI preference behavior should be localized and documented in the surface-specific master ref as well as here.
