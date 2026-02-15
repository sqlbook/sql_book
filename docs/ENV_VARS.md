# Environment Variables

## Application
- `RAILS_ENV`
  - `production` in staging/prod.
- `RAILS_MASTER_KEY`
  - Optional for current setup (not required in staging today).
  - Set only if/when encrypted credentials are introduced.
- `RAILS_LOG_LEVEL`
  - Optional; default `info`.
- `PORT`
  - Web port; platform may inject.
- `APP_HOST`
  - Required in deploy environments.
  - Staging: `staging.sqlbook.com`
  - Production: `sqlbook.com`
- `APP_PROTOCOL`
  - Required in deploy environments.
  - Use `https`.

## Database
- `POSTGRES_HOST`
  - Database host.
- `POSTGRES_USER`
  - Database username (defaults to `sqlbook` if unset).
- `POSTGRES_PASSWORD`
  - Database password.
- `POSTGRES_READONLY_PASSWORD`
  - Password for read-only query role used by query execution service.

## Redis / Jobs / Realtime
- `REDIS_URL`
  - Redis connection URL for cache, Sidekiq, and ActionCable.

## Email/Auth (SES)
- `AWS_REGION`
  - Use EU region (example: `eu-west-1`).
- `AWS_ACCESS_KEY_ID`
  - IAM access key for SES sending.
- `AWS_SECRET_ACCESS_KEY`
  - IAM secret for SES sending.

## Error Monitoring
- `SENTRY_DSN`
  - Optional. If set, Sentry initializes in production.

## Deploy-time parity check
Run:

```bash
bin/predeploy-check staging
bin/predeploy-check production
```

This validates required vars plus host/protocol rules for each environment.
