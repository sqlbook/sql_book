# Engineering Guardrails

## Query Execution Safety
- All user-generated SQL must run with read-only DB permissions.
- Enforce workspace/tenant scoping server-side, not only in prompts/UI.
- Block DDL/DML and unsafe SQL statements.
- Apply statement timeout and max returned rows.
- Log prompt, generated SQL, execution metadata, and errors for auditability.

## LLM SQL Assistant
- LLM output is a draft, not trusted execution input.
- Validate and sanitize generated SQL before execution.
- Show generated SQL to users before run.
- Preserve explicit user control to edit SQL manually.

## Connector Ingestion
- Use connector-specific execution strategy:
  - SQL database connectors default to live read-only querying in v1.
  - API/SaaS connectors can use selective sync/materialization when live-query is impractical.
- Use incremental sync + webhooks for sync-based connectors when providers support them.
- Track sync status, retries, and dead-letter failures.
- Keep provider credentials encrypted and scoped minimally.

## Ops Baseline
- Use separate staging and production environments.
- Keep secrets out of git; rotate periodically.
- Add backup/restore runbook for Postgres before launch.
- Add uptime + error monitoring before accepting production users.

## UI Messaging Safety
- For toast actions that link inside the app, prefer `path` (for example `/app/workspaces`) instead of absolute URLs.
- If an internal absolute `https://*.sqlbook.com/...` URL is provided, normalize it to a relative path before rendering.
- Reserve absolute URLs for genuinely external destinations (for example docs/help center).
- Toast locale copy is plain text; do not use HTML entities like `&apos;` in toast translation strings.
- See `docs/TOASTS_MASTER_REF.md` for toast-specific copy/encoding/interpolation rules.
- For workspace chat, all deterministic system copy (UI labels, validation text, status rows, fixed executor/planner text) must use locale keys and ship with `en` + `es` entries.
