# Staging Core Functionality Checklist

Last updated: 2026-03-21

## Purpose
Define the minimum stable functionality that must pass before any production cutover work proceeds.

## Exit criteria
- Every item below is marked pass in staging.
- Any failure has a tracked fix and is re-tested to pass.
- Environment parity checks pass (`bin/predeploy-check staging` and `bin/check-no-staging-hardcodes`).

## 1) Platform health
- [ ] `https://staging.sqlbook.com/up` returns healthy response.
- [ ] Web service boots without startup exceptions.
- [ ] Worker service boots and processes jobs.
- [ ] Postgres and Redis connectivity verified from app logs.
- [ ] Frontend assets load without digested asset 404s (for example `/assets/application-*.css`).

## 2) Auth and sessions
- [ ] Signup flow completes from staging UI.
- [ ] Login OTP/code email is delivered.
- [ ] Magic link/code authentication works end-to-end.
- [ ] Logout invalidates session and redirects correctly.

## 3) Workspace and data source lifecycle
- [ ] Create workspace succeeds.
- [ ] Invite member flow succeeds (if enabled in current build).
- [ ] User/Read-only members do not see workspace card settings link/icon.
- [ ] Direct unauthorized workspace URL redirects to `/app/workspaces` with `Workspace not available` toast.
- [ ] Team tab member status/actions auto-refresh when invite state changes (no manual page refresh).
- [ ] Data sources home page renders grouped sections for external databases and first-party capture.
- [ ] PostgreSQL datasource wizard validates connection details and advances to table selection.
- [ ] PostgreSQL datasource creation succeeds and returns to the datasource home page.
- [ ] Datasource settings side panel opens from the datasource name cell and behaves as 50/50 desktop split or full takeover below `1024px`.
- [ ] Chat datasource actions work without server errors (`datasource.list`, `datasource.validate_connection`, `datasource.create`) for owner/admin roles.
- [ ] Data source API routes respond correctly for owner/admin and reject user/read-only roles.
- [ ] Chat write actions work without server errors (rename/invite flows).
- [ ] Migration `20260309102000_add_idempotency_key_to_chat_action_requests` is applied in staging.

## 4) Tracking and event ingestion
- [ ] Tracking script snippet renders with staging host/protocol values.
- [ ] Browser connects to Action Cable at staging websocket URL.
- [ ] Turbo Stream websocket subscriptions connect on `/cable` for app UI realtime updates.
- [ ] Page view/session/click events arrive in staging database.
- [ ] Event save job runs without repeated retries/failures.

## 5) Query path
- [ ] Query editor datasource dropdown shows external datasource names correctly.
- [ ] Query editor schema browser shows the selected datasource's allowed table metadata.
- [ ] Query execution still runs against one selected datasource at a time.
- [ ] SQL query execution works for allowed read-only queries.
- [ ] Blocked/unsafe queries are rejected as designed.
- [ ] Query results render in UI without server errors.

## 6) Observability and safety checks
- [ ] `bin/predeploy-check staging` passes in staging env.
- [ ] `bin/check-no-staging-hardcodes` passes on current commit.
- [ ] Error logs show no unresolved critical exceptions for core paths.
- [ ] If frontend assets changed in this deploy, run `bundle exec rails dartsass:build` and then `RAILS_ENV=production bundle exec rails assets:clobber assets:precompile`.

## Run notes
- Keep evidence links/log snippets in PR description or deploy notes.
- If a step is intentionally out of scope for the current release, mark it as deferred with reason and owner.
