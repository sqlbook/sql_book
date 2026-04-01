# sqlbook Project Context

## Product Summary
sqlbook lets users:
- connect multiple data sources inside a workspace
- capture first-party events via sqlbook tracking code
- connect external SQL databases and query them live (without ingesting full copies in v1)
- query data with SQL and save queries/visualizations
- apply reusable workspace visualization themes with dark/light variants
- build dashboards from saved queries (MVP in progress)
- expand over time to additional connectors (for example third-party SaaS and API-backed sources)

## Current Constraints
- Founder-led rebuild with heavy LLM support.
- Prioritize low operational complexity and clear runbooks.
- EU hosting/data residency is preferred for privacy and compliance posture.
- Workspace remains the tenancy boundary for data sources, queries, and dashboards.
- Tenant isolation and read-only guarantees are non-negotiable for user-executed queries.
- For v1 external database connectors, store connector metadata/credentials only; do not ingest full external datasets.

## Reference docs
- Query editor, query library, saved-query identity, and chat-query card behavior are documented in `docs/QUERIES_MASTER_REF.md`.

## Near-Term Priorities
1. Stable staging environment (`staging.sqlbook.com`).
2. Reliable auth email delivery in staging/production.
3. Workspace-scoped chat v1 for workspace/team actions using LLM-first runtime + shared tool registry, with risk-based confirmation and localization.
4. Generalize data sources from first-party-only to multi-type connectors.
5. Implement connector adapter architecture and strict query safety guardrails.
6. Ship first external connector (PostgreSQL, live query mode).
7. Update data source/query UX for connector catalog + connector-aware schema explorer, while keeping the query model structurally ready for later multi-source selection.
8. ECharts-based query-owned visualizations with workspace theming and documented API contracts.
9. Dashboard MVP on top of the new connector model.

## Current Chat Runtime Snapshot
- Chat execution scope now includes workspace/team actions plus the phase-1 datasource/query actions (`datasource.list`, `datasource.validate_connection`, `datasource.create`, `query.list`, `query.run`, `query.save`, `query.update`, `query.rename`, `query.delete`, `thread.rename`).
- Shared tool registry is now the canonical server execution interface for chat actions.
- Chat turn orchestration is now server-authoritative:
  - `Chat::TurnOrchestrator` is the thin controller-facing boundary
  - it still contains a small number of bounded pre-interpreter guards for direct SQL, confirmation replies, and persisted setup/follow-up flows
  - `Chat::Interpreter` is the canonical LLM-enabled interpreter path
  - `Chat::RuntimeService` proposes intent
  - `Chat::IntentReconciler` normalizes payloads and explicit references before execution
  - reconciliation, preflight, confirmation, idempotency, and truth refresh are app-owned
- Public API docs for workspace/team/datasource/query contracts are available at `/dev/api` (API routes remain auth-protected).
- `docs/API_MASTER_REF.md` is the canonical reference for OpenAPI/Scalar setup and API-doc maintenance rules.
- Destructive writes (`workspace.delete`, `member.remove`) require confirmation; other allowed writes, including `member.update_role`, auto-run after preflight.
- Invite flows require full identity (`first_name`, `last_name`, `email`) plus an explicit `role` before `member.invite` executes.
- Datasource setup flows are staged and should collect missing details progressively rather than asking for every field in one turn.
- Datasource setup detection must not hijack clear query requests that merely mention a connected database or datasource in passing.
- Query chat is single-source in phase 1; it can list saved queries, run read-only queries, save the most recent executed query into the query library, rename saved queries, and delete saved queries with confirmation. If multiple datasources or tables plausibly match the question, chat should ask a clarifying follow-up before execution.
- Query chat can now also update an existing saved query in place when the latest thread draft is clearly a refinement of that saved query; exact duplicate saves are blocked by a server-owned fingerprint rather than the LLM guessing about duplicates.
- Query continuity for card state/save affordances is narrower than full query-title drift review: same-query edits such as column or `LIMIT` changes stay attached, while source/order flips such as `oldest users` -> `newest users` should break back out into a fresh unsaved query result.
- Datasource viewing is allowed for workspace `OWNER`, `ADMIN`, and `USER`; datasource creation, validation, update, and deletion remain owner/admin-only.
- Chat context is assembled from recent transcript + structured recent action results, not shadow LLM-maintained memory records.
- Unresolved-next-step state is now persisted via `ChatPendingFollowUp`, not only inferred from recent assistant wording.
- Query save-name conflict and query-scope clarification continuity now read/write `ChatPendingFollowUp` directly; no separate wrapper stores should be added back around those flows.
- Query continuity inside chat now uses durable per-thread query references rather than a single "recent query" slot, so multiple queries discussed in one thread stay resolvable over time and thread-local drafts can stay distinct from saved-library queries.
- Structured execution data can now carry:
  - `presentation` for app-rendered UI blocks such as query cards
  - `next_actions` for executable optional suggestions
  - `follow_up` for persisted unresolved-next-step state
- SQL-changing `query.update` now performs a saved-query title review so rename suggestions are only emitted when the old title is actually stale.
- That title review remains model-first and now includes the user's latest refinement request as context, so the model can sanity-check titles after edits without falling back to heuristic naming rules.
- Saved queries can optionally expose chat provenance (`Chat source`) when they originated from chat and the current viewer can still access that private source thread.
- Chat write lifecycle now separates semantic identity from attempt identity so old-thread retries create fresh attempts without replaying stale results.
- Rate limiting is now in a targeted first-pass rollout for auth, chat, query execution, and data source validation/create. Later expansion phases are tracked in [RATE_LIMITING_MASTER_REF.md](/Users/chrispattison/sql_book/docs/RATE_LIMITING_MASTER_REF.md).
- Chat surface uses split sibling panels (history + conversation) on desktop and overlay history on mobile (`<=760px`).
- Message stream keeps the latest content in view (bottom-oriented UX), hides per-message timestamps, and shows animated `Thinking...` status rows.

## Architecture Principles
- Optimize for shipping and maintainability over maximal control.
- Prefer managed services when they remove operational burden.
- Keep strong tenant isolation and read-only guarantees for user-executed queries.
- Keep first-party captured events centralized with strict per-tenant access controls.
- Default external connectors to least-privilege, read-only, live-query access.
- Avoid cross-source join/federation complexity in phase 1; design it explicitly before implementation.
- Keep query-editor metadata contracts generic enough that multiple datasources can be selected later without another first-party-only rewrite.
- Introduce new infrastructure only when measurable bottlenecks justify it.
