# Next Session Handoff: Render Staging

Last updated: 2026-02-15

## Service and goal
- Service: Render hosting stack for sqlbook staging (web app, worker, Postgres, Redis, domain/TLS).
- Why we use it: run a production-like staging environment for deployment validation.
- Outcome we need: stable staging platform (`https://staging.sqlbook.com`) plus completed SES email auth flow.

## Current status
- Local app runs successfully via `bin/dev-local`.
- Database setup works locally.
- Render was selected as the staging provider.
- Render staging Postgres has been created.
- Render staging Redis has been created.
- Render web service is created and healthy at `https://sqlbook-staging-web.onrender.com/up`.
- Render worker is created and healthy (`sqlbook-staging-worker`).
- DB bootstrap has been run from the web shell.
- Custom domain + TLS are active and healthy at `https://staging.sqlbook.com/up`.
- Master reference for ongoing Render work: `docs/RENDER_MASTER_REF.md`.
- Master reference for AWS SES/email setup: `docs/AWS_SES_MASTER_REF.md`.
- Master reference for auth and invitation behavior: `docs/AUTH_MASTER_REF.md`.
- Mailer URL generation now uses env-driven host/protocol in production config (`APP_HOST`/`APP_PROTOCOL`).
- Latest staging auth email links are confirmed working to `staging.sqlbook.com`.

## Where to resume
Continue from staging hardening and smoke tests:
1. Rotate remaining DB admin secret (`POSTGRES_PASSWORD`) if required
2. Wait for SES production access approval, then validate email to non-verified recipients
3. Confirm latest GitHub CI remains healthy after follow-up changes

## AWS/SES setup status
- Fresh AWS account created and SES onboarding started in `eu-west-1`.
- Old AWS SES DKIM records were removed from Namecheap.
- SES identities are now verified (`hello@sqlbook.com` and `sqlbook.com`).
- IAM user `sqlbook-ses-staging` access keys were created.
- Render env vars now use real AWS creds and auth email flow works in sandbox with verified recipient.
- SES production access request has been submitted and is pending AWS review.

## CI status
- Latest CI issues (`lint`, `scan_ruby`, `deploy`) were addressed by commit `9b36fd8`.
- Confirm latest GitHub Actions run is green (or deploy job is intentionally skipped unless Kamal deploy is enabled).

## App fixes deployed
- `fd0f4d5`: tracking script URL now respects `APP_HOST`/`APP_PROTOCOL` (fixes staging cert mismatch asset load).
- `47234d3`: OTP service now resends code when one already exists (fixes repeated signup no-email behavior).
- `bc7a2b9`: guard workspace views against missing owner records.
- `ad1b22c`: prevent `/app/workspaces` crash when `app.current_data_source_uuid` setting is unset.
- `8ec02bf`: action mailer default URL options now use `APP_HOST`/`APP_PROTOCOL`.

## DNS note to carry forward
- Root/apex `sqlbook.com` currently resolves to a legacy unrelated host.
- This does not block staging (`staging.sqlbook.com`) but must be intentionally corrected before production cutover.

## Hardening already completed
- Redis policy changed to `noeviction`
- `POSTGRES_READONLY_PASSWORD` rotated
- `SECRET_KEY_BASE` rotated
- `SENTRY_DSN` removed from staging services

## Postgres values to use (staging)
- Name: `sqlbook-staging-db`
- Database: `sqlbook_staging`
- User: `sqlbook`
- Region: EU region (use the same region for all services)
- Plan: `Basic-256mb`
- Storage: `5GB` (current configured value)
- Autoscaling: disabled
- High availability: disabled

## After resources exist
Use:
- `docs/RENDER_MASTER_REF.md` as canonical Render state/config reference
- `docs/STAGING_RENDER_PLAN.md` for full step-by-step setup
- `docs/ENV_VARS.md` for environment variables

## Important implementation note
- `config/master.key` is not present in this repo.
- For current staging deploy flow, set `SECRET_KEY_BASE` and do not set `RAILS_MASTER_KEY`.

## First message to send next session
Paste this to resume quickly:

```
We are resuming Render staging setup for sqlbook.
I have created <tell me which services are created>.
Please give me the exact next clicks and exact env vars to enter.
```
