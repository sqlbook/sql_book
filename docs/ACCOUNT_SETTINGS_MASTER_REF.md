# Account Settings Master Reference

Last updated: 2026-03-05

## Service and goal
- Service: authenticated user account settings in sqlbook.
- Why we use it: allow users to manage personal account profile details safely.
- Outcome we need: predictable profile updates with secure email-change verification.

## Purpose
Single source of truth for account-settings routes, behavior, verification rules, and known follow-ups.

Related references:
- `docs/AUTH_MASTER_REF.md` for login/signup/invitation flows.
- `docs/WORKSPACES_MASTER_REF.md` for workspace-scoped settings and role behavior.
- `docs/EMAILS_MASTER_REF.md` for full email inventory, trigger locations, and template mapping.
- `docs/TRANSLATIONS_MASTER_REF.md` for locale preference and translation architecture details.

## Core routes
- `GET /app/account-settings` -> `App::AccountSettingsController#show`
- `PATCH /app/account-settings` -> `App::AccountSettingsController#update`
- `DELETE /app/account-settings` -> `App::AccountSettingsController#destroy`
- `GET /app/account-settings/verify-email/:token` -> `App::AccountSettingsController#verify_email`

## Current form scope
- Account settings UI now uses tabs:
  - `General` (default) -> first name, last name, email update form
    - includes `Language` preference field (`en`/`es`)
  - `Notifications` -> placeholder tab (no editable controls yet)
  - `Delete Account` -> account deletion guidance and confirmation flow
- Tabs use shared tab component behavior:
  - top spacing: `0`
  - spacing below tabs: `40px`

## Delete account behavior
- Delete account is confirmed via an inline message dialog in the `Delete Account` tab.
- Dialog includes a per-workspace decision table for all workspaces where the current user is an `accepted owner`.
- Transfer candidates are restricted to `accepted` members only.
- Per owned workspace:
  - if at least one accepted non-owner member exists, actor must choose:
    - a `New owner` member, or
    - `Delete workspace`
  - if no accepted non-owner member exists, workspace is automatically marked:
    - `No team members, workspace will be deleted.`
- Confirm CTA remains disabled until all required workspace decisions are selected.
- On success:
  - account is deleted
  - workspaces are deleted or transferred per selection
  - user session is reset
  - redirect goes to `/`
  - success toast is shown
- On unresolved or failure states:
  - redirect returns to `/app/account-settings?tab=delete_account`
  - error toast is shown

## Email change data model
Email changes use a pending-verification state on `users`:
- `pending_email` (string)
- `email_change_verification_token` (string, unique index)
- `email_change_verification_sent_at` (datetime)

## Update behavior
- Name-only update:
  - applies immediately via `PATCH /app/account-settings`
  - success toast is shown
- Locale-only update:
  - applies immediately via `PATCH /app/account-settings`
  - stores selected locale in `users.preferred_locale`
  - updates current session locale for immediate UI change
- Email-change request:
  1. User submits updated email on account settings page.
  2. Current `users.email` remains unchanged.
  3. New value is stored in `users.pending_email`.
  4. Verification token and sent timestamp are generated.
  5. Verification email is sent to the current/old email address.
  6. UI shows verification-pending toast.

## Verification behavior
- Token lifetime: 1 hour.
- Valid + unexpired token:
  - `users.email` is replaced with `users.pending_email`.
  - `users.pending_email` is cleared.
  - user is redirected to `/app/workspaces`.
  - success toast is shown.
- Repeated clicks on the same valid token (within the 1-hour window) are treated as successful/idempotent.
- Expired token:
  - pending verification fields are cleared.
  - user is redirected to `/app/account-settings`.
  - error toast is shown.
- Invalid token:
  - user is redirected to `/auth/login`.
  - error toast is shown.

## Security and integrity rules
- Verification link is sent to old email (current account owner), not to pending email.
- Token comparison uses secure compare.
- Verification fails if:
  - token does not match
  - token is expired
  - pending email is blank
  - pending email uniqueness would be violated at confirm time
- If requested email is already in use at update time, pending verification is not created.

## Toast behavior
- Success: profile updated
- Information: verification pending (includes `%{email_current}` and `%{email_new}` with emphasized variable styling in toast body)
- Success: email verified
- Error: verification expired/invalid
- Error: email unavailable
- Error: generic update failure
- Success: account deleted (`account_deleted_success`)
- Error: account deletion unresolved workspace actions (`account_delete_unresolved_workspaces`)
- Error: generic account deletion failure (`account_delete_failed`)

## Account deletion emails
- Confirmation to deleted user:
  - mailer: `AccountMailer.account_deletion_confirmed`
  - recipient: deleted account email (captured before delete)
  - subject: `Account Deletion Confirmed.`
- Ownership transfer notice to new owner:
  - mailer: `WorkspaceMailer.workspace_owner_transferred`
  - recipient: selected new owner
  - subject: `You've been made the Owner of %{workspace_name}`
  - destination link: workspace home (`/app/workspaces/:id`)
- Full cross-domain email catalog and trigger map: `docs/EMAILS_MASTER_REF.md`.
- Scope note:
  - self-service account deletion (`DELETE /app/account-settings`) runs `AccountDeletionService` with email notifications enabled.
  - super-admin deletion of another user in `/app/admin/users/:id` explicitly disables those emails.

## Environment safety rules
- No hardcoded staging/production hostnames in account-settings links.
- Verification email URL uses route URL helpers with env-driven Action Mailer host/protocol (`APP_PROTOCOL`, `APP_HOST`).
- Email variable values (`current email` / `new email`) are rendered with emphasized text styling in verification email content.

## Known constraints
- No dedicated resend-verification endpoint yet.
- No explicit rate limit yet for repeated email-change requests.
- Email verification completion currently signs in the token owner session.

## Follow-up candidates
- Add explicit resend verification action with cooldown/rate limit.
- Add account-level audit log for profile/email changes.
- Add settings area for notification preferences.
