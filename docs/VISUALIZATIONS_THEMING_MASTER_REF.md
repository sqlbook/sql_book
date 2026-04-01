# Visualizations and Theming Master Reference

Last updated: 2026-04-01

## Purpose
Single source of truth for query-owned visualizations, workspace visualization themes, the built-in system theme, and the current phase-1 parity scope for the ECharts migration.

Related references:
- `docs/QUERIES_MASTER_REF.md`
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`
- `docs/API_MASTER_REF.md`

## Core principles
- Visualizations are query-owned.
- Each query can have zero or more saved visualizations, with one saved visualization per `chart_type`.
- Visualization state is stored as structured domain data, not raw persisted ECharts option blobs.
- Workspace themes are reusable across query visualizations.
- The built-in `Default Theming` theme is visible everywhere, read-only, and cannot be deleted.
- Sharing/public embedding is intentionally deferred in this phase, but the editor and API keep a placeholder section so future work can attach cleanly.

## Persistence model
- `QueryVisualization`
  - `query_id`
  - `chart_type`
  - `theme_reference`
  - `data_config`
  - `appearance_config_dark`
  - `appearance_config_light`
  - `other_config`
- `VisualizationTheme`
  - `workspace_id`
  - `name`
  - `theme_json_dark`
  - `theme_json_light`
  - `default`

Important:
- Legacy `queries.chart_type` and `queries.chart_config` are removed.
- `QueryVisualization` uniqueness is `(query_id, chart_type)`.
- There is no dual-write or compatibility layer for the old Chart.js implementation.

## Built-in system theme
- System reference key: `system.default_theming`
- Display name: `Default Theming`
- It is:
  - visible in every workspace theme library
  - selectable in visualization editors
  - read-only
  - undeletable
  - non-editable
- It becomes the effective default whenever a workspace has not chosen a workspace-owned default theme.

## Theme behavior
- User-created themes store explicit dark/light ECharts theme JSON.
- The built-in system theme is defined with sqlbook semantic tokens and resolved to concrete mode colors at runtime.
- A query visualization selects a theme by `theme_reference`.
- Per-chart appearance overrides are stored separately for dark and light mode and deep-merge over the selected theme variant at render time.

## Editor structure
- Query editor visualization UX:
  - gallery-first
  - selecting a type opens that type's draft editor
  - nothing persists until the master query-editor save action runs
- Query visualization editor sections:
  - `Preview`
  - `Data`
  - `Appearance`
  - `Sharing`
  - `Other`
- Workspace Branding tab:
  - table of visible themes
  - create/edit/delete workspace themes
  - duplicate system or workspace themes
  - set workspace default
  - read-only view for the built-in system theme

## Current chart scope
- Phase-1 parity types:
  - `table`
  - `total`
  - `line`
  - `area`
  - `column`
  - `bar`
  - `pie`
  - `donut`
- Deferred types:
  - `stacked_area`
  - `stacked_column`
  - `stacked_bar`
  - `combo`
- Data-mapping scope in phase 1:
  - one x/dimension column where applicable
  - one y/value column where applicable
  - no multi-series editor
  - no ECharts dataset transform authoring UI

## Rendering contract
- ECharts-backed visualizations are rendered from:
  - query result rows/columns
  - structured `data_config`
  - resolved theme variant
  - per-chart appearance overrides
  - `other_config`
- Canonical ECharts integration approach:
  - `echarts/core`
  - tree-shaken chart/component registration
  - `dataset.source`
  - `encode`
- `table` and `total` remain first-class visualization types but are rendered by sqlbook-owned UI rather than ECharts.

## API surface
- Query visualization API:
  - `GET /api/v1/workspaces/:workspace_id/queries/:query_id/visualizations`
  - `GET /api/v1/workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type`
  - `PATCH /api/v1/workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type`
  - `DELETE /api/v1/workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type`
- Visualization theme API:
  - `GET /api/v1/workspaces/:workspace_id/visualization-themes`
  - `POST /api/v1/workspaces/:workspace_id/visualization-themes`
  - `GET /api/v1/workspaces/:workspace_id/visualization-themes/:id`
  - `PATCH /api/v1/workspaces/:workspace_id/visualization-themes/:id`
  - `DELETE /api/v1/workspaces/:workspace_id/visualization-themes/:id`
  - `POST /api/v1/workspaces/:workspace_id/visualization-themes/duplicate`
  - `PATCH /api/v1/workspaces/:workspace_id/visualization-themes/:id/default`

## Future chat/tooling compatibility
- Persisted visualization data stays domain-shaped so chat/tool callers do not need to generate raw ECharts option blobs.
- The visualization service layer is server-owned and reusable across UI, API, and future chat actions.
- Future requests such as `show me this as a stacked bar chart` should build on:
  - the structured visualization schema
  - chart-registry validation
  - stable `query_id + chart_type` targeting
  - server-side option building
- `echarts-mcp` is not a runtime dependency in this phase, but this architecture should not block future MCP/tool-assisted visualization generation.

## Explicitly deferred
- Public chart URLs
- Embed code / iframe output
- Authenticated vs public visibility toggles
- Dashboard widget/layout work
