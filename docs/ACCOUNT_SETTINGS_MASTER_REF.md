# Account Settings Master Reference

Last updated: 2026-02-20

## Service and goal
- Service: authenticated user account settings in sqlbook.
- Why we use it: allow users to manage personal account profile details safely.
- Outcome we need: predictable profile updates with secure email-change verification.

## Purpose
Single source of truth for account-settings routes, behavior, verification rules, and known follow-ups.

Related references:
- `docs/AUTH_MASTER_REF.md` for login/signup/invitation flows.
- `docs/WORKSPACES_MASTER_REF.md` for workspace-scoped settings and role behavior.

## Core routes
- `GET /app/account-settings` -> `App::AccountSettingsController#show`
- `PATCH /app/account-settings` -> `App::AccountSettingsController#update`
- `GET /app/account-settings/verify-email/:token` -> `App::AccountSettingsController#verify_email`

## Current form scope
- First name
- Last name
- Email address

## Email change data model
Email changes use a pending-verification state on `users`:
- `pending_email` (string)
- `email_change_verification_token` (string, unique index)
- `email_change_verification_sent_at` (datetime)

## Update behavior
- Name-only update:
  - applies immediately via `PATCH /app/account-settings`
  - success toast is shown
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
- Add settings areas for notification preferences and account deletion controls.
