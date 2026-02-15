# Environment Parity Checklist

Last updated: 2026-02-15

## Purpose
Prevent staging/production configuration drift and stop staging-only values leaking into production.

## Required conventions
- Same application code in both environments; behavior differs via environment variables.
- No hardcoded deployment hosts in app logic.
- `RAILS_ENV=production` for both Render staging and Render production services.

## Host and protocol contract
- Staging:
  - `APP_HOST=staging.sqlbook.com`
  - `APP_PROTOCOL=https`
- Production:
  - `APP_HOST=sqlbook.com`
  - `APP_PROTOCOL=https`

## Service-level parity
Set and validate on both Web and Worker:
- `POSTGRES_HOST`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_READONLY_PASSWORD`
- `REDIS_URL`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `RAILS_LOG_LEVEL`
- `APP_HOST`
- `APP_PROTOCOL`

## Predeploy gate
Run before any deploy:

```bash
bin/predeploy-check staging
bin/predeploy-check production
```

Interpretation:
- `staging` check should pass only with `APP_HOST=staging.sqlbook.com`
- `production` check should pass only with `APP_HOST=sqlbook.com`

## Runtime verification
After deploy, run in each Render shell:

```bash
bundle exec rails runner 'p Rails.application.config.action_mailer.default_url_options'
```

Expected:
- staging: `{protocol: "https", host: "staging.sqlbook.com"}`
- production: `{protocol: "https", host: "sqlbook.com"}`

## DNS prerequisite for production cutover
- `staging.sqlbook.com` must remain CNAME to Render staging web service.
- Apex/root `sqlbook.com` must be intentionally pointed to the production target before go-live.
- Do not rely on historical/unknown apex records.
