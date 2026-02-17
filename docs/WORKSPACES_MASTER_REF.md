# Workspace Master Reference

Last updated: 2026-02-17

## Service and goal
- Service: workspace lifecycle, membership, permissions, and deletion behavior in sqlbook.
- Why we use it: workspaces are the core tenancy boundary for data sources, queries, dashboards, and team access.
- Outcome we need: predictable workspace ownership, safe deletion behavior, and clear team management UX.

## Purpose
Single source of truth for workspace routes, role permissions, delete flows, invite behavior, and known hardening gaps.

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
  - `DELETE /app/workspaces/:workspace_id/members/:id` -> remove member (role constrained)

## Roles and authorization
- Roles in `Member`:
  - `OWNER` (1)
  - `ADMIN` (2)
  - `READ_ONLY` (3)
- Current enforced rules:
  - only owners can delete a workspace
  - owner delete tab/action is hidden from non-owners
  - member removal requires acting user role to outrank target role
  - owner member cannot be removed through the member-destroy route

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

### Invite constraints and UX
- Inviting as `OWNER` is blocked server-side.
- Inviting an existing workspace member is blocked server-side.
- Success and failure toasts are shown for invite attempts.
- On successful invite, pending member should appear in team table on refresh/redirect.

## Invitation accept/reject behavior
- Accept:
  - pending member becomes accepted
  - invitation token cleared
- Reject:
  - pending member row removed
  - inviter gets rejection email
  - invitee user removed only if they belong to no workspaces

## Workspace delete behavior
1. Owner confirms deletion.
2. Workspace and related entities are destroyed.
3. All other users who were members of that workspace are notified by email.
4. Deleting user is redirected to `/app/workspaces`.
5. Toast confirms full success or partial notification failure.

## Email behaviors (workspace domain)
- Invite email: `WorkspaceMailer.invite`
- Invite rejection email: `WorkspaceMailer.invite_reject`
- Workspace deleted notification email: `WorkspaceMailer.workspace_deleted`
- Sender defaults to `noreply@sqlbook.com` via `ApplicationMailer`.
- Internal links in mailers should always be generated from route helpers + env-driven host/protocol config.

## Environment safety rules
- Do not hardcode staging/production hostnames in workspace controllers/mailers/views.
- Use internal path helpers (`app_workspace_path`, `app_workspaces_path`, etc.) for in-app navigation.
- For absolute links (emails), use route URL helpers with Action Mailer host/protocol from env config.
- Toast action links should use `path` where possible so rendering stays environment-safe.

## Current hardening backlog (workspace)
- Add resend-invite endpoint/flow with dedicated server-side rate limits.
- Add audit log trail for workspace membership and role changes.
- Decide long-term legal strategy for invited users before explicit terms acceptance.
- Add dedicated request specs for invite email delivery failures.
