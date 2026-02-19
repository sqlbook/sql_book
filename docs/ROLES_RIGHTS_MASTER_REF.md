# Roles and Rights Master Reference

Last updated: 2026-02-19

## Purpose
Single source of truth for workspace role capabilities, route-level enforcement, and UI affordance expectations.

## Role model
Roles are workspace-scoped via `members.role`.

- `OWNER` (1)
- `ADMIN` (2)
- `USER` (3)
- `READ_ONLY` (4)

## Capability matrix

### Workspace index/navigation
- Route scope: `GET /app/workspaces`
- Owner: allow
- Admin: allow
- User: allow
- Read-only: allow

### Workspace settings
- Route scope: `GET/PATCH /app/workspaces/:id`
- Owner: allow
- Admin: allow
- User: deny
- Read-only: deny

### Workspace deletion
- Route scope: `DELETE /app/workspaces/:id`
- Owner: allow
- Admin: deny
- User: deny
- Read-only: deny

### Team management
- Route scope:
  - `POST /app/workspaces/:workspace_id/members`
  - `POST /app/workspaces/:workspace_id/members/:id/resend`
  - `DELETE /app/workspaces/:workspace_id/members/:id`
- Owner: allow (except owner row cannot be deleted)
- Admin: allow (cannot manage equal/higher role members)
- User: deny
- Read-only: deny

### Data source management
- Route scope:
  - `GET/POST/PUT/DELETE /app/workspaces/:workspace_id/data_sources...`
  - `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/set_up`
- Owner: allow
- Admin: allow
- User: deny
- Read-only: deny

### Query library/read
- Route scope:
  - `GET /app/workspaces/:workspace_id/queries`
  - `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries`
  - `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:id`
- Owner: allow
- Admin: allow
- User: allow
- Read-only: allow

### Query write
- Route scope:
  - `POST /app/workspaces/:workspace_id/data_sources/:data_source_id/queries`
  - `PUT /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:id`
  - `PUT /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:id/chart_config`
- Owner: allow
- Admin: allow
- User: allow
- Read-only: deny

### Query deletion
- Route scope: `DELETE /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:id`
- Owner: allow (any query)
- Admin: allow (any query)
- User: allow only when query author is self
- Read-only: deny

### Dashboard read
- Route scope:
  - `GET /app/workspaces/:workspace_id/dashboards`
  - `GET /app/workspaces/:workspace_id/dashboards/:id`
- Owner: allow
- Admin: allow
- User: allow
- Read-only: allow

### Dashboard write
- Route scope:
  - `GET /app/workspaces/:workspace_id/dashboards/new`
  - `POST /app/workspaces/:workspace_id/dashboards`
- Owner: allow
- Admin: allow
- User: allow
- Read-only: deny

### Dashboard deletion
- Route scope: `DELETE /app/workspaces/:workspace_id/dashboards/:id`
- Owner: allow
- Admin: allow
- User: deny
- Read-only: deny

## UI affordance expectations
UI should hide actions users cannot perform, but server remains source of truth.

- Team tab:
  - Invite form visible for Owner/Admin only.
  - Member row actions visible only when acting role outranks target member role.
- Query library:
  - Create-new affordance hidden for Read-only.
  - Delete action hidden unless role is allowed to delete that specific query.
- Dashboards:
  - Create-new affordance hidden for Read-only.
  - Delete action hidden for User and Read-only.
- Workspace settings:
  - Settings/edit controls visible for Owner/Admin only.

## Enforcement and UX on deny
- Forbidden action returns redirect with toast:
  - title: `Action not allowed`
  - body: `Your workspace role does not allow this action.`
- Deny behavior is implemented server-side in controller guards, independent of UI visibility.
- Invitation accept redirect behavior:
  - owner/admin -> workspace settings route
  - user/read-only -> workspaces list

## Environment safety constraints
- No hardcoded staging hostnames in role-dependent links/buttons.
- Use Rails path/url helpers so behavior remains staging/production-safe.
- Internal toast links should use path helpers or normalized internal paths.

## Open follow-ups
- Add role change audit log (who changed what role and when).
- Introduce explicit `In Review` checks in release QA for role matrix paths.
- Define feature-level nuances for `User` and `Read-only` around future dashboards/query editing workflows.
