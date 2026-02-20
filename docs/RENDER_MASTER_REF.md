# Render Master Reference (Staging + Production)

Last updated: 2026-02-20

## Purpose
Single source of truth for Render setup decisions, actual configured values, and rollout progress.

## Scope
- Staging: `staging.sqlbook.com` (infrastructure complete)
- Production: `sqlbook.com` (not started in this thread)

## Region policy
- Use one EU region for all Render services in an environment.
- Staging services must all match the same region.

## Staging status tracker
- [x] PostgreSQL created
- [x] Redis (Render Key Value) created
- [x] Web service (Docker) created
- [x] Worker service (Docker + Sidekiq) created
- [x] Environment variables set on Web + Worker
- [x] DB bootstrap commands run
- [x] `staging.sqlbook.com` domain configured
- [x] TLS issued and verified
- [ ] Smoke tests complete

## Staging resources

### PostgreSQL
- Status: created
- Service name: `sqlbook-staging-db`
- Database name: `sqlbook_staging`
- User: `sqlbook`
- Plan: `Basic-256mb`
- Storage: `5 GB` (intentionally reduced from earlier 15 GB suggestion)
- Autoscaling: disabled
- High availability: disabled
- PostgreSQL version: 18 (default)
- Datadog integration: not configured
- Networking: external inbound blocked (no `0.0.0.0/0` rule)

### Redis (Key Value)
- Status: created
- Service name: `sqlbook-staging-redis`
- Plan: `Starter`
- Region: `Frankfurt (EU Central)`
- Policy: `noeviction`
- External inbound access: blocked (no inbound IP rules configured)

### Web service
- Status: created and healthy on Render default URL
- Service name: `sqlbook-staging-web`
- Runtime target: Docker
- Branch: `main`
- Region: `Frankfurt (EU Central)`
- Instance type: `Starter`
- Root directory: blank
- Health check: `/up` returns healthy response at `https://sqlbook-staging-web.onrender.com/up`
- Custom domain: `https://staging.sqlbook.com/up` healthy

### Worker service
- Status: created and healthy
- Service name: `sqlbook-staging-worker`
- Runtime target: Docker
- Start command: `bundle exec sidekiq -q events` (set via Docker Command)
- Health signal: Sidekiq booted and connected to Redis

## Environment variables (staging target)
Set on both Web and Worker unless noted otherwise:
- `RAILS_ENV=production`
- `SECRET_KEY_BASE=<generated in Render>`
- `POSTGRES_HOST=<render postgres internal hostname>`
- `POSTGRES_USER=<render postgres username>`
- `POSTGRES_PASSWORD=<render postgres password>`
- `POSTGRES_READONLY_PASSWORD=<strong generated password>`
- `REDIS_URL=<render redis internal url>`
- `AWS_REGION=<chosen EU SES region>`
- `AWS_ACCESS_KEY_ID=<ses key id>`
- `AWS_SECRET_ACCESS_KEY=<ses secret>`
- `RAILS_LOG_LEVEL=info`

Web only:
- `PORT=3000` (optional if Render injects)
- `APP_HOST=staging.sqlbook.com`
- `APP_PROTOCOL=https`
- `WEB_CONCURRENCY=1`

Current note:
- `config/master.key` is not present in repo; use `SECRET_KEY_BASE` and do not set `RAILS_MASTER_KEY` for current staging deploy.
- SES credentials are currently placeholders/blank until AWS setup is completed.

## One-time DB bootstrap (staging)
Run in Web service shell:

```bash
bundle exec rails db:prepare
PGUSER=sqlbook PGPASSWORD="$POSTGRES_PASSWORD" PGHOST="$POSTGRES_HOST" \
psql -d sqlbook_production -c "CREATE ROLE sqlbook_readonly WITH LOGIN PASSWORD '$POSTGRES_READONLY_PASSWORD';" || true
PGUSER=sqlbook PGPASSWORD="$POSTGRES_PASSWORD" PGHOST="$POSTGRES_HOST" \
psql -d sqlbook_events_production -c "GRANT SELECT ON clicks TO sqlbook_readonly;"
PGUSER=sqlbook PGPASSWORD="$POSTGRES_PASSWORD" PGHOST="$POSTGRES_HOST" \
psql -d sqlbook_events_production -c "GRANT SELECT ON page_views TO sqlbook_readonly;"
PGUSER=sqlbook PGPASSWORD="$POSTGRES_PASSWORD" PGHOST="$POSTGRES_HOST" \
psql -d sqlbook_events_production -c "GRANT SELECT ON sessions TO sqlbook_readonly;"
```

## Asset deploy guardrail (staging + production)
If any frontend assets changed (SCSS/JS/views that reference assets), precompile assets in production mode before or during deploy.

Run in Web service shell:

```bash
RAILS_ENV=production bundle exec rails assets:clobber assets:precompile
```

Why:
- Production has `config.assets.compile = false`.
- If precompile is skipped, the app can request digested assets that do not exist and render unstyled pages (`/assets/application-*.css` 404).

## Notes and decisions
- 2026-02-15: Chose 5 GB staging Postgres storage to minimize initial cost.
- 2026-02-15: Renamed Render project from `My project` to `sqlbook`.
- 2026-02-15: Proceeding with staging resources under current `Production` environment label for momentum; environment naming cleanup can happen after staging is green.
- 2026-02-15: Redis maxmemory policy was changed to `noeviction` for Sidekiq durability.
- 2026-02-15: `SENTRY_DSN` was removed from staging services; services remained healthy.
- 2026-02-15: Mailer URL host/protocol now comes from `APP_HOST`/`APP_PROTOCOL` in production config (no hardcoded `sqlbook.com`).
- 2026-02-19: ActionCable route mounted at `/cable` for Turbo Stream UI refresh behavior (workspace members/in-app invitation notifications).
- 2026-02-20: Added explicit ActionCable mount for `/events/in` alongside `/cable` so tracking websocket ingestion and Turbo Stream UI updates both remain active.

## Hardening checklist (next)
- [ ] Rotate remaining setup-exposed secret (`POSTGRES_PASSWORD`)
- [x] Rotate `POSTGRES_READONLY_PASSWORD`
- [x] Rotate `SECRET_KEY_BASE`
- [x] Remove placeholder `SENTRY_DSN` from staging services
- [x] Configure SES credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and run auth email flow test
- [x] Change Redis `Maxmemory Policy` to `noeviction`
- [x] Confirm worker continues processing jobs after Redis policy change
- [x] Complete staging smoke tests (signup/login email + background events + `/up`)*
- [x] Confirm auth email links point to `staging.sqlbook.com` in staging

*Note: Email flow is validated in SES sandbox mode with a verified recipient email. Production SES approval is still pending for unrestricted recipient delivery.

## Environment parity guardrail (staging vs production)
To avoid staging URLs leaking into production:
- Keep code environment-driven (`APP_HOST`, `APP_PROTOCOL`) and avoid hardcoded hostnames.
- Set staging web/worker:
  - `APP_HOST=staging.sqlbook.com`
  - `APP_PROTOCOL=https`
- Set production web/worker (when created):
  - `APP_HOST=sqlbook.com`
  - `APP_PROTOCOL=https`
- Verify runtime in each environment:
  - `bundle exec rails runner 'p Rails.application.config.action_mailer.default_url_options'`

## Recent fixes deployed
- 2026-02-15: `fd0f4d5` - Use `APP_HOST`/`APP_PROTOCOL` for tracking script URL instead of hardcoded `sqlbook.com`.
- 2026-02-15: `47234d3` - Resend OTP when one already exists to prevent silent no-email on repeated signup attempts.
- 2026-02-15: `9b36fd8` - CI stabilization: skip Kamal deploy unless explicitly enabled and ignore Brakeman outdated-tool exit code.
- 2026-02-15: `bc7a2b9` - Guard workspace UI against missing owner records.
- 2026-02-15: `ad1b22c` - Prevent `/app/workspaces` 500 when DB setting `app.current_data_source_uuid` is missing.
- 2026-02-15: `8ec02bf` - Use `APP_HOST`/`APP_PROTOCOL` for Action Mailer URL options.
- 2026-02-19: Mount ActionCable at `/cable` so Turbo Stream subscriptions can receive live updates.
- 2026-02-20: Keep ActionCable mounted on both `/cable` (Turbo Streams) and `/events/in` (tracking script ingestion).
