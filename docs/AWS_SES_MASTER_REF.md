# AWS SES Master Reference (Staging)

Last updated: 2026-02-15

## Service and goal
- Service: Amazon SES (Simple Email Service) in AWS.
- Why we use it: send transactional auth emails (one-time login codes) from sqlbook in staging/production.
- Outcome we need: reliable email delivery from `sqlbook.com` identities, wired into Render app env vars.

## Purpose
Single source of truth for AWS SES setup required for staging auth/login email delivery.

## Scope
- Environment: staging
- App domain: `staging.sqlbook.com` (Render)
- Email domain: `sqlbook.com` (SES + DNS)
- AWS region: `eu-west-1` (Europe/Ireland)
- Current sender identity: `hello@sqlbook.com`

## Current status
- [x] Fresh AWS account created
- [x] AWS region selected: `eu-west-1`
- [x] SES onboarding started
- [x] Namecheap DNS cleanup performed for stale AWS DKIM records
- [x] ProtonMail domain re-activation/verification complete
- [x] SES email identity added: `hello@sqlbook.com`
- [x] SES email identity verified: `hello@sqlbook.com`
- [x] SES domain identity added: `sqlbook.com`
- [x] SES DNS records added for domain identity
- [x] SES domain identity verified: `sqlbook.com`
- [x] SES sandbox status reviewed (sandbox vs production access)
- [x] IAM API credentials created for application use (`sqlbook-ses-staging`)
- [x] Render env vars updated with real AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- [x] Staging auth email smoke test passed (using SES-verified recipient while in sandbox)
- [ ] SES production access request approved
- [x] Support-case follow-up submitted to AWS with transactional use-case details

## DNS state notes (Namecheap)
- Keep: `staging` CNAME -> `sqlbook-staging-web.onrender.com.`
- Keep: ProtonMail verification TXT record(s)
- Keep (temporary): existing apex/root `A` record for now unless intentionally decommissioning root domain
- Removed: old AWS SES DKIM CNAME records from prior setup

Important:
- Apex/root `sqlbook.com` currently points to a legacy unrelated host.
- Staging email links are now corrected via app config (`APP_HOST`/`APP_PROTOCOL`), independent of this apex DNS state.
- Production launch requires intentional root DNS cutover.

## Required app env vars (Render web + worker)
- `AWS_REGION=eu-west-1`
- `AWS_ACCESS_KEY_ID=<set from IAM user access key>`
- `AWS_SECRET_ACCESS_KEY=<set from IAM user secret access key>`

## SES setup plan (next actions)
1. Wait for SES production access request outcome (case opened in AWS Support).
2. After approval, validate auth email delivery to non-verified recipient addresses.
3. If needed after initial success, replace `AmazonSESFullAccess` with least-privilege IAM policy.

## Open risks
- Account is currently in SES sandbox, so only verified recipients receive email.
- Production access approval timing is external to the project.
- Root domain DNS is not yet aligned to sqlbook infrastructure.
