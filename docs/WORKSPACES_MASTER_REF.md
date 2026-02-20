# Workspace Master Reference

Last updated: 2026-02-19

## Service and goal
- Service: workspace lifecycle, membership, permissions, and deletion behavior in sqlbook.
- Why we use it: workspaces are the core tenancy boundary for data sources, queries, dashboards, and team access.
- Outcome we need: predictable workspace ownership, safe deletion behavior, and clear team management UX.

## Purpose
Single source of truth for workspace routes, role permissions, delete flows, invite behavior, and known hardening gaps.

Related reference:
- `docs/ROLES_RIGHTS_MASTER_REF.md` for canonical role capability matrix and UI affordance expectations.

## Core routes
- Workspaces:
  - `GET /app/workspaces` -> list user workspaces
  - `GET /app/workspaces/new` -> new workspace screen
  - `POST /app/workspaces` -> create workspace (+ owner membership)
  - `GET /app/workspaces/:id` -> workspace settings/details tabs
  - `PATCH /app/workspaces/:id` -> update workspace name
  - `DELETE /app/workspaces/:id` -> delete workspace (owner only)
- Workspace team members:
  - `POST /app/workspaces/:workspace_id/members` -> invite member
  - `POST /app/workspaces/:workspace_id/members/:id/resend` -> resend pending invitation
  - `DELETE /app/workspaces/:workspace_id/members/:id` -> remove member (role constrained)

## Roles and authorization
- Roles in `Member`:
  - `OWNER` (1)
  - `ADMIN` (2)
  - `USER` (3)
  - `READ_ONLY` (4)
- Controller-level capability matrix:
  - Workspace index (`GET /app/workspaces`): all accepted members
  - Workspace settings (`GET/PATCH /app/workspaces/:id`): owner/admin only
  - Workspace delete (`DELETE /app/workspaces/:id`): owner only
  - Team management routes (`members#create`, `members#destroy`, `members#resend`): owner/admin only
  - Data source settings routes (`data_sources*`, `data_sources/set_up#index`): owner/admin only
  - Query library (`GET /app/workspaces/:workspace_id/queries`): all roles
  - Query write (`data_sources/queries#create|update|chart_config`): owner/admin/user
  - Query destroy (`data_sources/queries#destroy`):
    - owner/admin: any query
    - user: own queries only
    - read-only: forbidden
  - Dashboard read (`dashboards#index|show`): all roles
  - Dashboard create (`dashboards#new|create`): owner/admin/user
  - Dashboard destroy (`dashboards#destroy`): owner/admin only
- Authorization UX:
  - forbidden actions redirect with error toast:
    - title: `Action not allowed`
    - body: `Your workspace role does not allow this action.`

## Unauthorized workspace access handling
- Workspace-scoped controllers use a shared membership lookup guard.
- If workspace id is invalid or current user is not an accepted member:
  - redirect to `/app/workspaces`
  - show error toast:
    - title: `Workspace not available`
    - body: `You don't have permission to access that workspace.`

## Team table actions
- Pending invited members:
  - `Resend Invitation` (rotates invitation token + sends fresh invite email)
  - `Delete` (removes pending membership without notifying invitee)
- Accepted members:
  - `Delete` (removes membership; user account remains)
- Revoked/invalid invitation links:
  - redirect to home
  - show information toast that invitation is no longer valid
- Resend cooldown:
  - server-enforced 10-minute cooldown before another resend is allowed
  - when blocked, info toast explains cooldown

## Workspace creation flow
1. Authenticated user creates workspace with a name.
2. Workspace record is created.
3. Creator gets `Member` row with owner role + accepted status.
4. If this is first workspace, user is sent to data source onboarding.

## Team invitation flow
Source: `WorkspaceInvitationService`

1. Owner/admin submits invite form from team tab.
2. Service finds or creates invitee `User` by email.
   - for newly invited users, terms fields are left blank until invitation acceptance
3. Service creates `Member` row on workspace with:
   - `status: PENDING`
   - `invitation: SecureRandom.base36`
   - role from inviter
   - `invited_by` set to inviter user
4. Service sends workspace invite email.
5. UI redirects back to team tab with toast feedback.
6. Invite creation + invite-email send are transactional so failed delivery does not leave orphan pending members.

### Invite constraints and UX
- Inviting as `OWNER` is allowed only when inviter is an `OWNER`.
- Inviting as `OWNER` is blocked server-side for `ADMIN` inviters.
- Inviting an existing workspace member is blocked server-side.
- Success and failure toasts are shown for invite attempts.
- On successful invite, pending member appears on refresh/redirect and via realtime updates for active viewers.

## Invitation accept/reject behavior
- Accept:
  - pending member becomes accepted
  - invitation token cleared
  - post-accept redirect:
    - owner/admin -> workspace settings route (`/app/workspaces/:id`)
    - user/read-only -> workspaces list (`/app/workspaces`)
- Reject:
  - pending member row removed
  - inviter gets rejection email
  - invitee user removed only if they belong to no workspaces

## Membership status behavior
- `PENDING` membership does not grant active workspace access.
- Only `ACCEPTED` memberships count for:
  - workspace visibility in `/app/workspaces`
  - role-based authorization checks across workspace features

## User deletion cleanup
- When a user is deleted and that user was the final member of a workspace, the workspace is automatically destroyed.
- If a deleted user was not the final member, the workspace remains.
- This prevents orphaned workspaces with zero members when user deletion cascades through `members`.

## Realtime updates (team + invitations)
- Membership create/update/destroy events broadcast Turbo Stream refresh events.
- Team tab (`/app/workspaces/:id?tab=team`) subscribes to a workspace-members stream:
  - status/action cells refresh without manual page reload after accept/reject/delete/resend flows.
- App pages subscribe to a per-user stream:
  - pending invitation toast appears for active signed-in users when an invite is created.
- Transport requirement:
  - ActionCable mounted at `/cable` for Turbo Stream subscriptions.
  - This is separate from tracking/event ingestion websocket usage.

## Workspace delete behavior
1. Owner confirms deletion.
2. Workspace and related entities are destroyed.
3. All other users who were members of that workspace are notified by email.
4. Deleting user is redirected to `/app/workspaces`.
5. Toast confirms full success or partial notification failure.

## Email behaviors (workspace domain)
- Invite email: `WorkspaceMailer.invite`
- Invite rejection email: `WorkspaceMailer.invite_reject`
- Member removed email: `WorkspaceMailer.workspace_member_removed` (sent for accepted member removals in team management flow)
- Workspace deleted notification email: `WorkspaceMailer.workspace_deleted`
- Sender defaults to `noreply@sqlbook.com` via `ApplicationMailer`.
- Internal links in mailers should always be generated from route helpers + env-driven host/protocol config.

## Environment safety rules
- Do not hardcode staging/production hostnames in workspace controllers/mailers/views.
- Use internal path helpers (`app_workspace_path`, `app_workspaces_path`, etc.) for in-app navigation.
- For absolute links (emails), use route URL helpers with Action Mailer host/protocol from env config.
- Toast action links should use `path` where possible so rendering stays environment-safe.

## Current hardening backlog (workspace)
- Evaluate moving resend cooldown from app layer to explicit persisted invite-send timestamp and per-user/IP rate limiting.
- Add audit log trail for workspace membership and role changes.
- Decide long-term legal strategy for invited users before explicit terms acceptance.
- Add dedicated request specs for invite email delivery failures.
