# Admin Master Reference

Last updated: 2026-03-01

## Service and goal
- Service: super-admin-only control surfaces under `/app/admin/*`.
- Why we use it: provide a secure operations layer for platform-wide management features that are not workspace-scoped.
- Outcome we need: explicit, auditable access control with strict staging/production separation.

## Purpose
Single source of truth for admin surface scope, access model, routing, and operational guardrails.

Related references:
- `docs/TRANSLATIONS_MASTER_REF.md` for the first admin feature (`/app/admin/translations`).
- `docs/ROLES_RIGHTS_MASTER_REF.md` for workspace-level roles (owner/admin/user/read-only), which are separate from super-admin.
- `docs/ENV_VARS.md` for required bootstrap/env configuration.

## Scope boundaries
- Admin features live only under `/app/admin/*`.
- Admin access is account-level (`users.super_admin`), not workspace membership-based.
- Workspace role permissions do not grant admin namespace access.

## Access model
- Source of truth: `users.super_admin` (boolean, default `false`).
- Bootstrap helper:
  - env var: `SUPER_ADMIN_BOOTSTRAP_EMAILS`
  - behavior: if signed-in user email is allowlisted and `super_admin` is false, app auto-promotes to `super_admin: true`.
  - implementation entrypoint: `ApplicationController#ensure_bootstrap_super_admin!`
- Gate controller:
  - `App::Admin::BaseController`
  - requires authentication (`require_auth!`)
  - denies non-super-admin users.

## Deny behavior
- Redirect target: `/app/workspaces`
- Toast copy:
  - title: `Access denied`
  - body: `You don't have permission to access admin settings.`

## Current admin routes
- `GET /app/admin/translations`
- `PATCH /app/admin/translations`
- `POST /app/admin/translations/:id/translate-missing`
- `GET /app/admin/translations/:id/history`

## Environment separation guardrails
- `SUPER_ADMIN_BOOTSTRAP_EMAILS` must be set per environment (staging and production independently).
- Never copy staging bootstrap emails into production by default.
- Promotion state persists in DB once granted; removing an email from env allowlist does not auto-demote.
- Demotion is a deliberate DB action (`users.super_admin=false`) handled manually.

## Operational guidance
- Bootstrap first admin in staging:
  1. Set `SUPER_ADMIN_BOOTSTRAP_EMAILS` in staging env.
  2. Sign in with listed email.
  3. Confirm `/app/admin/translations` is accessible.
- Bootstrap first admin in production:
  1. Set production-specific allowlist.
  2. Repeat validation in production.
- Keep bootstrap lists minimal and review periodically.

## Security notes
- Admin namespace should not expose workspace-scoped actions unless explicitly required.
- Admin pages should avoid hardcoded hostnames and continue using env-safe helpers.
- All admin writes should produce auditable change records where feasible (implemented for translations via revision model).
