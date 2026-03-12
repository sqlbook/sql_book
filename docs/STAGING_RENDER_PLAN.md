# Staging Deployment Plan (Render)

Last updated: 2026-03-12

This runbook sets up `staging.sqlbook.com` on Render in an EU region.

## 1) Create Render resources

Create these services in the same Render region (EU):
- PostgreSQL instance
- Redis instance
- Web service (Rails app)
- Worker service (Sidekiq)

Use the same GitHub repo for both app services.

## 2) Configure app services

Web service:
- Runtime: Docker (use existing `Dockerfile`)
- Branch: `main`
- Start command: default from image is OK

Worker service:
- Runtime: Docker (same image)
- Branch: `main`
- Start command: `bundle exec sidekiq -q events`

Deploy branch policy:
- This repo deploys staging from `main`.
- Do not use `main:staging` for deploys.
- Hard rule: never run `git push origin main:staging` in this repository.
- Deploy with:

```bash
git push origin main
```

If pushed to `main:staging` by mistake, recover immediately:

```bash
git push origin main
git push origin --delete staging
```

## 3) Required environment variables

Set these on both Web and Worker:
- `RAILS_ENV=production`
- `POSTGRES_HOST=<render postgres internal hostname>`
- `POSTGRES_USER=<render postgres username>`
- `POSTGRES_PASSWORD=<render postgres password>`
- `POSTGRES_READONLY_PASSWORD=<generate strong password>`
- `REDIS_URL=<render redis internal url>`
- `AWS_REGION=eu-west-1` (or your chosen EU SES region)
- `AWS_ACCESS_KEY_ID=<ses smtp/api key id>`
- `AWS_SECRET_ACCESS_KEY=<ses smtp/api secret>`
- `SENTRY_DSN=<optional>`
- `RAILS_LOG_LEVEL=info`
- `APP_HOST=staging.sqlbook.com`
- `APP_PROTOCOL=https`

Set these on Web (and optionally Worker for strict env parity):
- `OPENAI_API_KEY=<required for workspace chat + translation generation>`
- `OPENAI_CHAT_MODEL=<set explicitly for deploy envs; recommended gpt-5.2 or gpt-5.4>`
- `OPENAI_TRANSLATIONS_MODEL=<optional; default gpt-4.1-mini>`
- `OPENAI_RESPONSES_ENDPOINT=<optional; default https://api.openai.com/v1/responses>`

Also set for Web:
- `PORT=3000` (Render usually injects this; setting explicitly is fine)

## 4) One-time database bootstrap

Open a shell in the Web service and run:

```bash
bundle exec rails db:prepare
POSTGRES_ADMIN_USER="$POSTGRES_USER" bash db/setup.sh production
```

Notes:
- This creates/migrates both primary and events production databases.
- The second command creates/grants read access for `sqlbook_readonly`.

## 5) Domain setup

In Render:
- Add custom domain: `staging.sqlbook.com` to Web service.

In DNS provider:
- Create the record Render asks for (usually CNAME).

Wait for TLS issuance to complete.

## 6) Production URL settings for staging

Production config now reads URL settings from environment variables:
- `APP_HOST`
- `APP_PROTOCOL`

These must be set correctly in staging (`staging.sqlbook.com` + `https`) to avoid wrong links in emails and scripts.

## 7) Smoke tests

After deploy:
- `GET /up` returns 200
- Frontend CSS/JS assets load without `/assets/application-*.css` or `/assets/application-*.js` 404s
- Sign-up/login code email is delivered
- Login succeeds with one-time code
- Background event jobs are consumed by worker
- `bundle exec rails db:migrate:status | grep 20260309102000` confirms chat idempotency migration is up
- chat requests do not log `Invalid schema for response_format` from runtime/planner Responses API calls

## 8) Launch gate for staging

Do not treat staging as ready until:
- auth emails work reliably
- DB migrations are repeatable
- production-mode assets are precompiled when frontend changes are deployed
- logs and errors are visible
- rollback path is documented
