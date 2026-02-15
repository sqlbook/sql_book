# Auth Master Reference

Last updated: 2026-02-15

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

## Routes (auth)
- Signup:
  - `GET /auth/signup` -> `Auth::SignupController#index`
  - `GET /auth/signup/new` -> sends OTP email for new account
  - `POST /auth/signup` -> verifies code and creates user
  - `GET /auth/signup/magic_link` -> verifies token via query params
  - `GET /auth/signup/resend` -> resend existing OTP
- Login:
  - `GET /auth/login` -> `Auth::LoginController#index`
  - `GET /auth/login/new` -> sends OTP email for existing account
  - `POST /auth/login` -> verifies code and signs in user
  - `GET /auth/login/magic_link` -> verifies token via query params
  - `GET /auth/login/resend` -> resend existing OTP
- Signout:
  - `GET /auth/signout` -> clears session
- Invitation:
  - `GET /auth/invitation/:id` -> show invite page
  - `POST /auth/invitation/:id/accept` -> accept invite and sign in invitee
  - `POST /auth/invitation/:id/reject` -> reject invite and notify inviter

## Signup flow
1. User submits name/email on signup page.
2. `Auth::SignupController#new` checks:
   - email present
   - user does not already exist
3. OTP service `create!` is called:
   - if OTP exists for email: resend existing code
   - else create new 6-digit OTP and send email
4. User submits OTP (or uses magic link).
5. `Auth::SignupController#create` verifies OTP.
6. On success:
   - user record is created
   - session is set (`current_user_id`)
   - redirect to workspace creation

## Login flow
1. User submits email on login page.
2. `Auth::LoginController#new` checks:
   - email present
   - user exists
3. OTP service `create!` behavior:
   - resend existing OTP if present
   - otherwise create and send new OTP
4. User submits OTP (or magic link).
5. `Auth::LoginController#create` verifies OTP.
6. On success:
   - session is set (`current_user_id`)
   - redirect to workspaces list

## OTP service behavior
Source: `app/services/one_time_password_service.rb`

- `create!`:
  - current behavior resends when OTP already exists (prevents silent no-email on repeat attempts)
- `resend!`:
  - sends existing token for the email
- `verify(token:)`:
  - compares token
  - deletes OTP on match

## Email triggers
- Signup OTP email:
  - `OneTimePasswordMailer.signup(email:, token:)`
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
  - status changes to `ACCEPTED`
  - invitation token cleared
  - session set to invitee user
- Reject:
  - member row removed
  - inviter receives rejection email
  - invitee user deleted if user has no remaining workspaces

## Current known behavior and constraints
- OTP has no explicit expiry window in current implementation.
- OTP token is not rotated on resend (resends existing token).
- Auth depends on working SES configuration in environment.
- In SES sandbox, recipient email must be verified for delivery tests.
- Email URL host/protocol are environment-driven in production via `APP_HOST`/`APP_PROTOCOL`.
- If those env vars are missing/wrong, auth emails can link to the wrong domain.

## Recent auth-related fixes deployed
- `47234d3`: resend existing OTP when one already exists.
- `fd0f4d5`: use `APP_HOST`/`APP_PROTOCOL` for tracking script URL to avoid staging cert mismatch errors.
- `8ec02bf`: use `APP_HOST`/`APP_PROTOCOL` for Action Mailer URL options.

## Next auth hardening candidates
- Add OTP expiration and retry/rate limits.
- Add audit logging around login/signup/invite acceptance.
- Add explicit test coverage for repeated signup/login send behavior.
- Review invite reject behavior that deletes users with no workspaces.
