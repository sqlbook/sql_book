# sqlbook Project Context

## Product Summary
sqlbook lets users:
- connect multiple data sources inside a workspace
- capture first-party events via sqlbook tracking code
- connect external SQL databases and query them live (without ingesting full copies in v1)
- query data with SQL and save queries/visualizations
- build dashboards from saved queries (MVP in progress)
- expand over time to additional connectors (for example third-party SaaS and API-backed sources)

## Current Constraints
- Founder-led rebuild with heavy LLM support.
- Prioritize low operational complexity and clear runbooks.
- EU hosting/data residency is preferred for privacy and compliance posture.
- Workspace remains the tenancy boundary for data sources, queries, and dashboards.
- Tenant isolation and read-only guarantees are non-negotiable for user-executed queries.
- For v1 external database connectors, store connector metadata/credentials only; do not ingest full external datasets.

## Near-Term Priorities
1. Stable staging environment (`staging.sqlbook.com`).
2. Reliable auth email delivery in staging/production.
3. Workspace-scoped chat v1 for workspace/team actions using LLM-first runtime + shared tool registry, with risk-based confirmation and localization.
4. Generalize data sources from first-party-only to multi-type connectors.
5. Implement connector adapter architecture and strict query safety guardrails.
6. Ship first external connector (PostgreSQL, live query mode).
7. Update data source/query UX for connector catalog + connector-aware schema explorer.
8. Dashboard MVP on top of the new connector model.

## Current Chat Runtime Snapshot
- Chat execution scope remains limited to workspace + team management actions.
- Shared tool registry is now the canonical server execution interface for chat actions.
- Public API docs for workspace/team contracts are available at `/dev/api` (API routes remain auth-protected).
- `docs/API_MASTER_REF.md` is the canonical reference for OpenAPI/Scalar setup and API-doc maintenance rules.
- High-risk writes (`workspace.delete`, `member.update_role`, `member.remove`) require confirmation; low-risk writes auto-run.
- Invite flows require full identity (`first_name`, `last_name`, `email`) before `member.invite` executes.
- Chat surface uses split sibling panels (history + conversation) on desktop and overlay history on mobile (`<=760px`).
- Message stream keeps the latest content in view (bottom-oriented UX), hides per-message timestamps, and shows animated `Thinking...` status rows.

## Architecture Principles
- Optimize for shipping and maintainability over maximal control.
- Prefer managed services when they remove operational burden.
- Keep strong tenant isolation and read-only guarantees for user-executed queries.
- Keep first-party captured events centralized with strict per-tenant access controls.
- Default external connectors to least-privilege, read-only, live-query access.
- Avoid cross-source join/federation complexity in phase 1; design it explicitly before implementation.
- Introduce new infrastructure only when measurable bottlenecks justify it.
