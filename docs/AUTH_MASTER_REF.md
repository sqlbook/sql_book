# Auth Master Reference

Last updated: 2026-02-19

## Service and goal
- Service: application authentication and invitation flows in sqlbook.
- Why we use it: passwordless access via one-time email codes and workspace invite acceptance/rejection.
- Outcome we need: reliable, understandable auth behavior across signup, login, magic links, and team invites.

## Purpose
Single source of truth for auth behavior, routes, email triggers, and key implementation rules.

## Auth architecture summary
- Session-based auth using `session[:current_user_id]`.
- Passwordless one-time password (OTP) sent by email for signup and login.
- OTP is currently six digits and stored in `one_time_passwords`.
- Successful OTP verification deletes the OTP record.
- Invitation flow is tokenized via `members.invitation` and handled separately from OTP.
- Session is rotated (`reset_session`) on login, signup, invitation accept, and signout.
- Signup requires server-side terms acceptance and persists terms metadata on the user record.

## Routes (auth)
- Signup:
  - `GET /auth/signup` -> `Auth::SignupController#index`
  - `GET /auth/signup/new` -> sends OTP email for new account
  - `POST /auth/signup` -> verifies code and creates user
  - `GET /auth/signup/magic_link` -> verifies token via query params
  - `GET /auth/signup/resend` -> resend rotated OTP
- Login:
  - `GET /auth/login` -> `Auth::LoginController#index`
  - `GET /auth/login/new` -> sends OTP email for existing account
  - `POST /auth/login` -> verifies code and signs in user
  - `GET /auth/login/magic_link` -> verifies token via query params
  - `GET /auth/login/resend` -> resend rotated OTP
- Signout:
  - `GET /auth/signout` -> resets session
- Invitation:
  - `GET /auth/invitation/:id` -> show invite page
  - `POST /auth/invitation/:id/accept` -> accept invite and sign in invitee
  - `POST /auth/invitation/:id/reject` -> reject invite and notify inviter
  - invalid/revoked invitation tokens redirect to home with information toast

## Signup flow
1. User submits name/email on signup page.
2. `Auth::SignupController#new` checks:
   - email present
   - terms accepted (server-side check)
   - user does not already exist
3. OTP service `create!` is called:
   - if OTP exists for email: resend rotated code
   - else create new 6-digit OTP and send email
4. User submits OTP (or uses magic link with `accept_terms=1`, `first_name`, and `last_name`).
5. `Auth::SignupController#create` verifies OTP.
6. On success:
   - user record is created
   - `terms_accepted_at` and `terms_version` are persisted
   - session is reset and then `current_user_id` is set
   - redirect to workspace creation

## Login flow
1. User submits email on login page.
2. `Auth::LoginController#new` checks:
   - email present
   - user exists
3. OTP service `create!` behavior:
   - resend rotated OTP if present
   - otherwise create and send new OTP
4. User submits OTP (or magic link).
5. `Auth::LoginController#create` verifies OTP.
6. On success:
   - session is reset and then `current_user_id` is set
   - redirect to workspaces list

## OTP service behavior
Source: `app/services/one_time_password_service.rb`

- `create!`:
  - resends when OTP already exists (prevents silent no-email on repeat attempts)
- `resend!`:
  - rotates token and sends replacement token for the email
- `verify(token:)`:
  - compares token
  - deletes OTP on match
- Delivery failures:
  - SES delivery errors are rescued and re-raised as `OneTimePasswordService::DeliveryError`
  - auth controllers handle this and redirect with a user-facing alert instead of returning 500

## Email triggers
- Signup OTP email:
  - `OneTimePasswordMailer.signup(email:, token:, magic_link_params:)`
- Login OTP email:
  - `OneTimePasswordMailer.login(email:, token:)`
- Workspace invite email:
  - `WorkspaceMailer.invite(member:)` to invitee
- Workspace invite rejection email:
  - `WorkspaceMailer.invite_reject(member:)` to inviter

## Invitation flow rules
Source: `WorkspaceInvitationService`

- Inviting creates or finds user by email.
- Creates `Member` with:
  - `status: PENDING`
  - `invitation: SecureRandom.base36`
  - role set by inviter
- Accept:
  - invited user must explicitly accept Terms of Use + Privacy Policy on invitation page
  - server enforces `accept_terms=1` before accepting invite
  - on accept, user `terms_accepted_at`/`terms_version` are updated to current values
  - status changes to `ACCEPTED`
  - invitation token cleared
  - session reset and set to invitee user
  - redirect target is role-aware:
    - owner/admin -> workspace settings route
    - user/read-only -> workspaces list
- Reject:
  - member row removed
  - inviter receives rejection email
  - invitee user deleted if user has no remaining workspaces

## In-app pending invitation notification
- On authenticated app pages (`/app/*`), if the current user has a pending invitation token and there is no higher-priority toast already queued, the app shows an information toast:
  - title: `New workspace invitation`
  - body: `You've been invited to join the %{workspace_name} workspace on sqlbook.`
  - action: `[View invitation]` -> `/auth/invitation/:token`
- Reject is intentionally not offered in this in-app toast; reject remains available on the invitation page itself.

## Environment parity and host behavior
- Production mailer URLs are env-driven by `APP_HOST` and `APP_PROTOCOL` via `config.action_mailer.default_url_options`.
- Mailer asset URLs (for example email logo image) are env-driven by `config.action_mailer.asset_host`.
- This prevents hardcoded staging hosts from leaking into auth links.
- Auth changes in this cycle do not introduce staging-specific host strings.

## Multi-environment session behavior (staging + production)
- With host-only cookies (current default behavior), `staging.sqlbook.com` and `sqlbook.com` keep separate browser sessions.
- You can be logged into both at the same time in separate tabs.
- This would only change if cookie domain is intentionally widened to `.sqlbook.com`.

## Current known behavior and constraints
- OTP has no explicit expiry window in current implementation.
- Auth depends on working SES configuration in environment.
- Pending workspace invitations do not count as active workspace membership.
- In SES sandbox, recipient email must be verified for delivery tests.
- Email URL host/protocol are environment-driven in production via `APP_HOST`/`APP_PROTOCOL`.
- If those env vars are missing/wrong, auth emails can link to the wrong domain.
- OTP paste/autofill behavior:
  - filling all 6 digits does not auto-submit
  - form validity is still recalculated so submit buttons enable correctly

## Recent auth-related fixes deployed
- `47234d3`: resend existing OTP when one already exists.
- `fd0f4d5`: use `APP_HOST`/`APP_PROTOCOL` for tracking script URL to avoid staging cert mismatch errors.
- `8ec02bf`: use `APP_HOST`/`APP_PROTOCOL` for Action Mailer URL options.
- Rotate OTP on resend (no OTP reuse).
- Reset session on login/signup/invitation accept/signout.
- Enforce terms acceptance server-side and persist `terms_accepted_at`/`terms_version`.
- Handle SES delivery rejections without returning 500 from auth entry points.
- Preserve signup context (`first_name`/`last_name`) through resend links and signup magic links.
- OTP controller now scopes listeners correctly across Turbo navigations and no longer auto-submits on paste.
- Added in-app pending invitation toast for active signed-in sessions with `[View invitation]` action.

## Next auth hardening candidates
- Add OTP expiration and retry/rate limits.
- Add audit logging around login/signup/invite acceptance.
- Add explicit test coverage for repeated signup/login send behavior.
- Review invite reject behavior that deletes users with no workspaces.
