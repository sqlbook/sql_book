# Staging Deployment Plan (Render)

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
- Start command: default from image is OK

Worker service:
- Runtime: Docker (same image)
- Start command: `bundle exec sidekiq -q events`

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
- Sign-up/login code email is delivered
- Login succeeds with one-time code
- Background event jobs are consumed by worker

## 8) Launch gate for staging

Do not treat staging as ready until:
- auth emails work reliably
- DB migrations are repeatable
- logs and errors are visible
- rollback path is documented
