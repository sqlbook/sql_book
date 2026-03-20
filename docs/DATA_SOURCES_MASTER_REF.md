# Data Sources Master Reference

Last updated: 2026-03-20

## Service and goal
- Service: workspace-scoped datasource management across first-party capture and external connectors.
- Why we use it: datasources are now a mixed-connector surface that powers query execution, chat actions, and future multi-source work.
- Outcome we need: safe workspace-scoped datasource creation, validation, management, and query execution semantics.

## Purpose
Single source of truth for datasource routes, connector scope, setup flow, permissions, security model, and phase-1 limitations.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`
- `docs/API_MASTER_REF.md`
- `docs/CHAT_MASTER_REF.md`
- `docs/TRANSLATIONS_MASTER_REF.md`
- `docs/ENGINEERING_GUARDRAILS.md`

## Phase-1 scope
- Multiple datasources can exist in a workspace.
- Supported datasource types:
  - `first_party_capture`
  - `postgres`
- Current external-database create flow is PostgreSQL-only.
- External SQL sources are queried live in v1.
- External SQL data is not ingested into sqlbook in v1.
- First-party capture setup still exists, but the new create flow emphasizes external PostgreSQL first.

## Core routes
App routes:
- `GET /app/workspaces/:workspace_id/data_sources`
  - grouped datasource home page
- `GET /app/workspaces/:workspace_id/data_sources/new`
  - datasource creation wizard
- `POST /app/workspaces/:workspace_id/data_sources/validate_connection`
  - validate PostgreSQL connection and discover selectable tables
- `POST /app/workspaces/:workspace_id/data_sources`
  - create datasource
- `GET /app/workspaces/:workspace_id/data_sources/:id`
  - datasource settings/management
- `PATCH /app/workspaces/:workspace_id/data_sources/:id`
  - current update path is capture-source URL management
- `DELETE /app/workspaces/:workspace_id/data_sources/:id`
  - delete datasource
- `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/set_up`
  - existing first-party capture setup surface

API routes:
- `GET /api/v1/workspaces/:workspace_id/data-sources`
- `POST /api/v1/workspaces/:workspace_id/data-sources/validate-connection`
- `POST /api/v1/workspaces/:workspace_id/data-sources`

Chat/tool actions:
- `datasource.list`
- `datasource.validate_connection`
- `datasource.create`

## Permissions
- Datasource management is owner/admin only across:
  - standalone UI
  - `/api/v1`
  - chat/tool execution
- User/read-only members must not be able to create, validate, update, or delete datasources.
- Server-side authorization remains authoritative even if UI affordances are hidden.

## Datasource home behavior
- Datasources home renders only connector families that currently have datasource rows:
  - `External databases`
  - `First-party data capture`
- External-database rows show:
  - datasource name
  - connector type
  - selected table count
  - related query count
- First-party capture rows show:
  - datasource name
  - total events
  - events this month
  - related query count

## Phase-1 create flow
Step 1:
- choose datasource family
- current enabled option: external database
- first-party capture and third-party library render as coming soon

Step 2:
- enter datasource name
- choose database type
- current enabled type: PostgreSQL
- provide connection details:
  - host
  - port
  - database name
  - username
  - password
  - optional flags carried in config (for example `extract_category_values`)
- clicking next validates the connection server-side

Step 3:
- select tables to allow for the datasource
- selected-table limit: `20`
- successful completion returns user to datasource home

Wizard-state note:
- essential datasource connection state is preserved across requests without relying solely on cache
- discovered tables are cached as an optimization, but the flow can repopulate them when needed

UI fidelity notes:
- datasource home uses the standard workspace `page-header` pattern with the inline create action beside `h1`
- datasource wizard should not add eyebrow copy or extra helper text unless it appears in the approved design
- datasource wizard labels follow the shared default label treatment unless a design explicitly overrides them

## Data model and connector semantics
- `DataSource.source_type` is the connector discriminator.
- `DataSource.status` tracks lifecycle state (`pending_setup`, `active`, `error`).
- PostgreSQL credentials are encrypted at rest in app DB.
- External connector metadata is stored in app DB, including selected tables and connection config.
- `selected_tables` is the allowlist used for phase-1 PostgreSQL connectors.

## Query execution semantics
- Query execution now routes through the datasource connector.
- Capture sources continue to use the existing first-party events path.
- External PostgreSQL sources use connector-driven read-only execution.
- External SQL guardrails include:
  - read-only execution path
  - safety validation before execution
  - statement timeout
  - row limit
- Cross-source joins are out of scope in phase 1.

## Security and tenancy model
- Workspace is the tenancy boundary for datasource records and permissions.
- First-party captured events remain in centralized storage with existing tenant isolation controls.
- External PostgreSQL sources are metadata-only in sqlbook:
  - we store connection metadata and encrypted credentials
  - we do not ingest full external datasets in phase 1
- External execution should always use least-privilege read-only credentials.
- Deterministic datasource serialization for UI/API/chat must not leak secrets.

## API and chat parity
- Datasource list/validate/create must remain aligned across:
  - standalone UI
  - OpenAPI-documented `/api/v1`
  - chat tool execution
- Chat/tool execution uses the same server-authoritative handlers and policy layer as the API-facing surface.
- Deterministic datasource chat copy is locale-key backed under `app.workspaces.chat.datasource.*`.

## Localization rules
- Datasource UI copy lives under `app.workspaces.data_sources.*`.
- Shared repeated labels should prefer `common.*`.
- Datasource deterministic API/chat result copy lives under `app.workspaces.chat.datasource.*`.
- New datasource copy is incomplete unless both `en` and `es` ship in the same change.

## Mixed-source stats semantics
- Capture sources keep event-driven stats.
- External PostgreSQL sources should not display misleading event-limit messaging.
- External rows/cards use connector type, selected table count, status, and related query count semantics instead.

## Phase-1 non-goals
- Cross-source query federation
- Non-PostgreSQL external SQL engines
- Third-party SaaS/API connector execution
- Visualization redesign
- External data ingestion pipelines

## Verification baseline
- `bundle exec rubocop`
- impacted datasource/query/chat/API specs
- OpenAPI validation and `/dev/api` review
- staging smoke checks for:
  - datasource home page
  - PostgreSQL wizard validation/create
  - datasource API routes
  - datasource chat actions
