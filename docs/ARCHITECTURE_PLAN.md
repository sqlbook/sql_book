# sqlbook Architecture Plan

## Goal
Build a reliable multi-source analytics/query SaaS that stays simple to operate early, then scales without a rewrite.

## Phase 1: Relaunch (now -> first paying users)
- Stack: Rails + Postgres + Redis in EU region.
- Hosting: managed PaaS preferred (Render/Fly) for lower ops burden; Kamal+VPS acceptable if cost is priority.
- Data model: keep app metadata and first-party event storage in Postgres (existing approach).
- Auth: email one-time codes with reliable provider (SES in EU region).
- Connector model:
  - generalize data sources from first-party capture only to multi-type connectors
  - support first-party capture + external PostgreSQL connector as first external source
  - external SQL connectors run live queries in v1 (no full dataset ingestion)
- Query safety:
  - read-only query role for user queries
  - strict tenant scoping and per-workspace authorization enforced server-side
  - preserve first-party RLS isolation semantics for captured events
  - statement timeout and row limits
  - single-statement + read-only execution rules for external connectors
  - query logging/audit
- Product scope:
  - tracking script ingestion (first-party)
  - connector catalog and setup UX
  - workspace-scoped chat assistant for workspace/team management actions (v1), powered by shared tool registry + LLM-first runtime
  - documented workspace/team API contracts at `/dev/api` (OpenAPI + Scalar), auth-protected at execution layer
  - API-doc maintenance governed by `docs/API_MASTER_REF.md`
  - SQL query editor
  - connector-aware schema explorer
  - saved queries
  - basic visualizations

Exit criteria:
- predictable deploy flow
- stable signup/login email delivery
- acceptable query latency for first-party and external PostgreSQL sources
- no tenant data leakage across workspaces under query and connector flows

## Phase 2: Product Expansion (growing usage)
- Add additional connectors (example: GA, Stripe, additional SQL engines).
- Strategy by connector type:
  - SQL databases: default to live read-only querying
  - API/SaaS connectors: use selective sync/materialization where live joins are impractical or rate-limited
  - avoid introducing blanket ingestion requirements for all connectors
- Add dashboard builder (Gridstack.js is fine for layout).
- Add query/result caching for repeated dashboard loads.
- Add observability:
  - error monitoring, structured logs, uptime checks
  - background job monitoring and retries

Exit criteria:
- connector reliability is acceptable (live-query and sync-based connectors as applicable)
- dashboard performance is acceptable under real workloads

## Phase 3: Scale Path (when Postgres becomes bottleneck)
- Keep Postgres for app metadata and transactional workflows.
- Add analytics warehouse path (likely ClickHouse) for very high-volume event analytics and heavy derived workloads.
- Use dual-store pattern:
  - Postgres: users/workspaces/config/small aggregates
  - ClickHouse: large event fact tables and heavy aggregations
- Introduce semantic/query translation or federation layer so app UX remains stable across mixed backends/sources.

Trigger signals for Phase 3:
- frequent slow analytical queries after indexing/partitioning
- unacceptable dashboard/query latency at current cost
- event volume growth that materially strains Postgres
- cross-source query requirements that cannot be met safely/performantly in current execution model
