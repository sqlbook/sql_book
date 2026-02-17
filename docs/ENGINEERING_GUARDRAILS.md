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
- Prefer ingesting source data into sqlbook over live per-request API reads.
- Use incremental sync + webhooks when providers support them.
- Track sync status, retries, and dead-letter failures.
- Keep provider credentials encrypted and scoped minimally.

## Ops Baseline
- Use separate staging and production environments.
- Keep secrets out of git; rotate periodically.
- Add backup/restore runbook for Postgres before launch.
- Add uptime + error monitoring before accepting production users.

