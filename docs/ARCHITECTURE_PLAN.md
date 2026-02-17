# sqlbook Architecture Plan

## Goal
Build a reliable analytics SaaS that stays simple to operate early, then scales without a rewrite.

## Phase 1: Relaunch (now -> first paying users)
- Stack: Rails + Postgres + Redis in EU region.
- Hosting: managed PaaS preferred (Render/Fly) for lower ops burden; Kamal+VPS acceptable if cost is priority.
- Data model: keep events and app data in Postgres (existing approach).
- Auth: email one-time codes with reliable provider (SES in EU region).
- Query safety:
  - read-only query role for user queries
  - per-workspace scoping enforced server-side
  - statement timeout and row limits
  - query logging/audit
- Product scope:
  - tracking script ingestion
  - SQL query editor
  - saved queries
  - basic visualizations

Exit criteria:
- predictable deploy flow
- stable signup/login email delivery
- acceptable query latency for target customers

## Phase 2: Product Expansion (growing usage)
- Add connectors (example: GA, Stripe) with ingest pipelines.
- Strategy for connectors:
  - ingest and store normalized copies in sqlbook
  - use scheduled sync + webhook increments where available
  - avoid live API reads for dashboard rendering
- Add dashboard builder (Gridstack.js is fine for layout).
- Add query/result caching for repeated dashboard loads.
- Add observability:
  - error monitoring, structured logs, uptime checks
  - background job monitoring and retries

Exit criteria:
- connector sync reliability is acceptable
- dashboard performance is acceptable under real workloads

## Phase 3: Scale Path (when Postgres becomes bottleneck)
- Keep Postgres for app metadata and transactional workflows.
- Add analytics warehouse path (likely ClickHouse) for very high-volume event analytics.
- Use dual-store pattern:
  - Postgres: users/workspaces/config/small aggregates
  - ClickHouse: large event fact tables and heavy aggregations
- Introduce semantic/query translation layer so app UX remains stable across backends.

Trigger signals for Phase 3:
- frequent slow analytical queries after indexing/partitioning
- unacceptable dashboard/query latency at current cost
- event volume growth that materially strains Postgres

