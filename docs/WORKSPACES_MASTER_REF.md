# Workspace Master Reference

Last updated: 2026-02-22

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
  - `GET /app/workspaces/:id` -> workspace home page
  - `GET /app/workspaces/:id/workspace-settings` -> workspace settings/details tabs
  - `PATCH /app/workspaces/:id/workspace-settings` -> update workspace name
  - `DELETE /app/workspaces/:id` -> delete workspace (owner only)
- Workspace team members:
  - `POST /app/workspaces/:workspace_id/members` -> invite member
  - `PATCH /app/workspaces/:workspace_id/members/:id` -> update member role (role constrained)
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
  - Workspace home (`GET /app/workspaces/:id`): all accepted members
  - Workspace settings (`GET/PATCH /app/workspaces/:id/workspace-settings`): owner/admin only
  - Workspace delete (`DELETE /app/workspaces/:id`): owner only
  - Team management routes (`members#create`, `members#update`, `members#destroy`, `members#resend`): owner/admin only
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
    - body: `You don't have permission to access this workspace.`

## Team table actions
- Pending invited members:
  - `Role` select (when acting role outranks target role; options constrained by acting role)
  - `Resend Invitation` (rotates invitation token + sends fresh invite email)
  - `Delete` (removes pending membership without notifying invitee)
- Accepted members:
  - `Role` select (when acting role outranks target role; options constrained by acting role)
  - `Delete` (removes membership; user account remains)
- Revoked/invalid invitation links:
  - redirect to home
  - show information toast that invitation is no longer valid
- Resend cooldown:
  - server-enforced 10-minute cooldown before another resend is allowed
  - when blocked, info toast explains cooldown

## Workspace settings save behavior
- General tab workspace-name form uses change detection:
  - `[Save Changes]` is disabled on initial render and only enables when the name value differs from the persisted value.
  - Form validity is still required before submit can enable.
- On successful workspace-name save:
  - success toast:
    - title: `Workspace settings saved`
    - body: `Your workspace name has been updated.`
- On unexpected save failure:
  - error toast:
    - title: `Couldn't save workspace settings`
    - body: `Please check your workspace name and try again.`

## Workspace breadcrumbs
- Breadcrumbs render on workspace-scoped app pages where workspace context exists (for example `/app/workspaces/:workspace_id/*`).
- Breadcrumbs do not render on workspace home/list route (`/app/workspaces`).
- Breadcrumb component is currently intentionally hidden in UI during navigation IA transition.
- Standard structure:
  - `Workspaces` / `<Workspace Name>` / `<Section>` / `<Optional Item>`
- Link behavior:
  - `Workspaces` is always a link to `/app/workspaces`.
  - On workspace home route (`/app/workspaces/:id`), `<Workspace Name>` is the current non-link breadcrumb item.
  - On workspace settings and child workspace routes, `<Workspace Name>` links to `/app/workspaces/:id` for all workspace roles.
  - Section and item links use internal route helpers only (no hardcoded hostnames).
- Narrow viewport behavior:
  - first item, last item, and `/` separators stay visible and are not clipped.
  - middle breadcrumb items can truncate with ellipsis (down to `...`) while preserving clickability.
  - truncated middle breadcrumb items show tooltip text on hover.

## Header navigation menus
- Header behavior is responsive by viewport width:
  - `<1024px`:
    - two right-aligned top-level menu icons are shown with 16px gap:
      - workspace menu icon: `ri-menu-line`
      - account menu icon: `ri-account-circle-line`
    - icon interaction model:
      - tapping icon opens dropdown and swaps icon to close (`ri-close-line`)
      - only one menu remains open at a time
      - `Esc` closes the open dropdown
    - workspace menu dropdown:
      - width: 180px
      - aligned so dropdown right edge matches workspace-menu icon right edge
      - opens 8px below icon
      - content:
        - `Workspace` heading
        - workspace switcher select
        - links: `Chat`, `Data Sources`, `Query Library`, `Dashboards`, `Settings`
    - account menu dropdown:
      - width: 160px
      - aligned so dropdown right edge matches account-menu icon right edge
      - opens 8px below icon
      - content:
        - `Account` heading
        - links: `Settings` (account settings), `Log out`
  - `>=1024px`:
    - workspace menu icon is hidden; account icon remains on the right
    - persistent workspace switcher is shown in header, 16px right of logo, width 160px
    - centered top nav link group is shown with routes:
      - `Chat` -> `/app/workspaces/:id`
      - `Data Sources` -> `/app/workspaces/:id/data_sources`
      - `Query Library` -> `/app/workspaces/:id/queries` (also active on nested query routes)
      - `Dashboards` -> `/app/workspaces/:id/dashboards`
      - `Settings` -> `/app/workspaces/:id/workspace-settings`
    - top nav styling:
      - 32px height items with 12px horizontal padding and 8px icon/text gap
      - inactive: gray-800 background, gray-700 border, gray-250 label, gray-500 icon
      - hover/active: gray-700 background, gray-500 border, cream-250 label, red-500 icon
      - first/last items use 8px outer corner radius

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
- `OWNER` is intentionally hidden in the current invite-form dropdown UI.
- Inviting an existing workspace member is blocked server-side.
- Success and failure toasts are shown for invite attempts.
- On successful invite, pending member appears on refresh/redirect and via realtime updates for active viewers.

### Role change constraints and UX
- Role updates are allowed only when acting role outranks target member role.
- Allowed role targets (server):
  - owner can set `OWNER`, `ADMIN`, `USER`, `READ_ONLY`
  - admin can set `ADMIN`, `USER`, `READ_ONLY`
- Current dropdown UI targets:
  - owner sees `ADMIN`, `USER`, `READ_ONLY`
  - admin sees `ADMIN`, `USER`, `READ_ONLY`
  - `OWNER` is intentionally hidden in UI for now (ownership transfer UX deferred).
- Invalid role updates are blocked server-side and return an error toast.
- Successful role updates return a success toast with updated user name and role.
- Role updates do not currently send an email notification.

## Invitation accept/reject behavior
- Accept:
  - pending member becomes accepted
  - invitation token cleared
  - post-accept redirect:
    - all roles -> workspace home route (`/app/workspaces/:id`)
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
- When a user is deleted and that user was the final accepted owner of a workspace, the workspace is automatically destroyed (even if non-owner members remain).
- If an accepted owner still remains after the user is deleted, the workspace remains.
- This prevents orphaned workspaces with zero members when user deletion cascades through `members`.
- When auto-deleting a workspace due ownerless state, remaining workspace users are notified via the existing workspace-deleted email.

## Realtime updates (team + invitations)
- Membership create/update/destroy events broadcast Turbo Stream refresh events.
- Team tab (`/app/workspaces/:id/workspace-settings?tab=team`) subscribes to a workspace-members stream:
  - status/action cells refresh without manual page reload after accept/reject/delete/resend flows.
- App pages subscribe to a per-user stream:
  - pending invitation toast appears for active signed-in users when an invite is created.
- Transport requirement:
  - ActionCable mounted at `/cable` for Turbo Stream subscriptions.
  - Tracking/event ingestion websocket remains mounted at `/events/in`.
  - Connection auth mode is split by endpoint:
    - `/cable`: app session-backed user auth (`session[:current_user_id]`)
    - `/events/in`: visitor payload + origin validation for tracking ingestion

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
- Use internal path helpers (`app_workspace_path`, `app_workspace_settings_path`, `app_workspaces_path`, etc.) for in-app navigation.
- For absolute links (emails), use route URL helpers with Action Mailer host/protocol from env config.
- Toast action links should use `path` where possible so rendering stays environment-safe.

## Current hardening backlog (workspace)
- Evaluate moving resend cooldown from app layer to explicit persisted invite-send timestamp and per-user/IP rate limiting.
- Add audit log trail for workspace membership and role changes.
- Decide long-term legal strategy for invited users before explicit terms acceptance.
- Add dedicated request specs for invite email delivery failures.
