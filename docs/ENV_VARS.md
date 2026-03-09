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

## Admin and translations
- `SUPER_ADMIN_BOOTSTRAP_EMAILS`
  - Comma-separated allowlist used to bootstrap `users.super_admin=true` on sign-in.
  - Must be configured independently per environment (staging and production).
  - Keep list minimal and review periodically.
- `OPENAI_API_KEY`
  - API key used by chat runtime/thread-title generation and admin translation "Translate missing" action.
  - Required only for LLM-assisted generation.
- `OPENAI_TRANSLATIONS_MODEL`
  - Optional model override for translation generation.
  - Defaults to `gpt-4.1-mini` if unset.
- `OPENAI_CHAT_MODEL`
  - Optional model override for workspace chat runtime/title generation.
  - Defaults to `gpt-5-mini` if unset.
- `OPENAI_RESPONSES_ENDPOINT`
  - Optional full Responses API endpoint for chat and translation flows.
  - Defaults to `https://api.openai.com/v1/responses`.
  - Use this to route by environment/provider without code changes.

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
