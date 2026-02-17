# Staging Core Functionality Checklist

Last updated: 2026-02-16

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
- [ ] Create data source succeeds with valid site URL.
- [ ] Data source verification flow reaches success state.

## 4) Tracking and event ingestion
- [ ] Tracking script snippet renders with staging host/protocol values.
- [ ] Browser connects to Action Cable at staging websocket URL.
- [ ] Page view/session/click events arrive in staging database.
- [ ] Event save job runs without repeated retries/failures.

## 5) Query path
- [ ] SQL query execution works for allowed read-only queries.
- [ ] Blocked/unsafe queries are rejected as designed.
- [ ] Query results render in UI without server errors.

## 6) Observability and safety checks
- [ ] `bin/predeploy-check staging` passes in staging env.
- [ ] `bin/check-no-staging-hardcodes` passes on current commit.
- [ ] Error logs show no unresolved critical exceptions for core paths.
- [ ] If frontend assets changed in this deploy, run `RAILS_ENV=production bundle exec rails assets:clobber assets:precompile`.

## Run notes
- Keep evidence links/log snippets in PR description or deploy notes.
- If a step is intentionally out of scope for the current release, mark it as deferred with reason and owner.
