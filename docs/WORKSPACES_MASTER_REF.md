# Workspace Master Reference

Last updated: 2026-03-20

## Service and goal
- Service: workspace lifecycle, membership, permissions, and deletion behavior in sqlbook.
- Why we use it: workspaces are the core tenancy boundary for data sources, queries, dashboards, and team access.
- Outcome we need: predictable workspace ownership, safe deletion behavior, and clear team management UX.

## Purpose
Single source of truth for workspace routes, role permissions, delete flows, invite behavior, and known hardening gaps.

Related references:
- `docs/ROLES_RIGHTS_MASTER_REF.md` for canonical role capability matrix and UI affordance expectations.
- `docs/EMAILS_MASTER_REF.md` for full mailer inventory and trigger ownership.
- `docs/CHAT_MASTER_REF.md` for chat-specific architecture, lifecycle, and localization rules.
- `docs/API_MASTER_REF.md` for documented workspace/team API contracts and docs maintenance rules.
- `docs/DATA_SOURCES_MASTER_REF.md` for datasource-specific routes, setup flow, and security semantics.

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
- Workspace chat:
  - `GET /app/workspaces/:workspace_id/chat/messages` -> incremental chat history
  - `POST /app/workspaces/:workspace_id/chat/messages` -> submit chat message and receive runtime decision/execution response
  - `POST /app/workspaces/:workspace_id/chat/actions/:id/confirm` -> confirm pending high-risk action
  - `POST /app/workspaces/:workspace_id/chat/actions/:id/cancel` -> cancel pending high-risk action
- Data sources:
  - `GET /app/workspaces/:workspace_id/data_sources` -> grouped datasource home page
  - `GET /app/workspaces/:workspace_id/data_sources/new` -> datasource creation wizard
  - `POST /app/workspaces/:workspace_id/data_sources/validate_connection` -> validate PostgreSQL connection and discover tables
  - `POST /app/workspaces/:workspace_id/data_sources` -> create datasource
  - `GET /app/workspaces/:workspace_id/data_sources/:id` -> datasource settings/management
  - `PATCH /app/workspaces/:workspace_id/data_sources/:id` -> update capture datasource URL
  - `DELETE /app/workspaces/:workspace_id/data_sources/:id` -> destroy datasource
- Workspace/team API v1 (auth-protected, documented via `/dev/api`):
  - `PATCH /api/v1/workspaces/:workspace_id`
  - `DELETE /api/v1/workspaces/:workspace_id`
  - `GET /api/v1/workspaces/:workspace_id/members`
  - `POST /api/v1/workspaces/:workspace_id/members`
  - `POST /api/v1/workspaces/:workspace_id/members/resend-invite`
  - `PATCH /api/v1/workspaces/:workspace_id/members/:id/role`
  - `DELETE /api/v1/workspaces/:workspace_id/members/:id`
  - `GET /api/v1/workspaces/:workspace_id/data-sources`
  - `POST /api/v1/workspaces/:workspace_id/data-sources/validate-connection`
  - `POST /api/v1/workspaces/:workspace_id/data-sources`
- OpenAPI/Scalar governance for these routes lives in `docs/API_MASTER_REF.md`.

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
  - Chat home (`GET /app/workspaces/:id`): all accepted roles
  - Chat read route (`chat/messages#index`): all accepted roles
  - Chat action route (`chat/messages#create`):
    - team visibility action (`member.list`) allowed only for owner/admin
    - mutating actions policy-gated by role and target constraints
  - Chat confirm/cancel routes (`chat/actions#confirm`, `chat/actions#cancel`): requester-only and workspace-scoped
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

## Workspace chat (v1)
- Workspace home surface is chat-first and workspace-scoped.
- Chat threads/history are isolated per-user within a workspace.
- v1 allowlist:
  - `workspace.update_name`
  - `workspace.delete`
  - `member.list`
  - `member.invite`
  - `member.resend_invite`
  - `member.update_role`
  - `member.remove`
  - `datasource.list`
  - `datasource.validate_connection`
  - `datasource.create`
- v1 blocked namespaces include:
  - `workspace.list/get/create`
  - `query.*`
  - `dashboard.*`
  - `billing.*`, `subscription.*`, `admin.*`, `super_admin.*`
- datasource note:
  - only `datasource.list`, `datasource.validate_connection`, and `datasource.create` are in scope
  - other datasource actions remain blocked until explicitly implemented
- Auto-run chat writes include `workspace.update_name`, `member.invite`, `member.resend_invite`, and `member.update_role`.
- Auto-run datasource chat writes include `datasource.validate_connection` and `datasource.create`.
- Destructive chat writes require explicit inline confirmation (`workspace.delete`, `member.remove`).
- Chat permission visibility should mirror workspace UI permissions:
  - `OWNER` / `ADMIN` can view workspace settings and the team member list
  - `USER` / `READ_ONLY` should not see the workspace settings nav item and should receive a permission response if they ask chat for the team member list
- Desktop/mobile workspace navigation should omit the workspace settings entry entirely for `USER` and `READ_ONLY` roles.
- Chat invite execution requires `first_name`, `last_name`, `email`, and `role`; runtime/planner follow-ups collect missing fields before execution.
- Invite follow-ups should ask for all currently missing invite fields together (for example `name + role` when only email is known).
- Natural role replies such as `I think admin` should still resolve to the intended role.
- Action payloads carry and enforce `workspace_id`, `thread_id`, and `message_id` scope.
- Thread/message route access is constrained to `created_by == current_user` within the current workspace.
- Image attachments are limited to `png/jpeg/webp/gif`, max 6 files, max 25MB each.
- Chat stream hides per-message timestamps; `Thinking` status uses animated ellipsis.
- Pending high-risk actions can be confirmed either from inline chat buttons or with explicit follow-up confirmation/cancellation chat messages.
- Pending confirmation cards are part of the workspace chat UI contract and should render visible `Confirm` / `Cancel` controls while the request is still pending.
- Permission-denied chat replies should say which workspace roles can perform the requested action, rather than only returning a flat refusal.
- Execution/preflight replies should be phrased by a response-composition layer rather than only echoing deterministic executor copy, so repeated denials or success messages do not sound robotic.
- Member-targeting chat actions should accept a unique member name as well as email/member id, so requests like "remove Chris Smith" resolve into a real pending action instead of a plain assistant prompt.
- Write idempotency dedupe requires `chat_action_requests.idempotency_key` migration; if missing temporarily, writes still execute and dedupe is skipped.
- Chat runtime/planner use strict Responses API JSON schema; dynamic tool arguments/payloads are serialized as JSON strings and parsed server-side. If logs show `Invalid schema for response_format`, fix the runtime/planner schema contract before treating the issue as prompt/model quality.
- Chat context should be rebuilt from recent transcript plus structured recent action results (`metadata.result_data`), not by introducing parallel LLM-maintained memory documents.
- Recent invite/member follow-ups should refresh against current workspace membership state before answering status/identity questions.
- Chat action lifecycle now distinguishes:
  - `action_fingerprint` for semantic action identity
  - `idempotency_key` for per-turn attempt identity
  - `source_message_id` for the user turn that created the attempt
  - `superseded_at` for stale pending confirmations
- Repeating the same write request in an old thread should create a fresh attempt for the new turn, rather than replaying or blocking on the old write record.

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
- On signed-in app pages without workspace context (`@workspace` not present), header shows:
  - logo (left)
  - account menu icon (right) with `Account` dropdown containing `Settings` and `Log out`
- Header shell is fixed-height across app pages:
  - height: 64px
  - padding: 16px top/bottom, 24px left/right
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
      - medium body size font (14px, regular)
      - inactive: gray-800 background, gray-700 border, gray-250 label, gray-500 icon
      - active: gray-850 background, gray-700 border, cream-250 label, red-500 icon
      - hover: gray-850 background, gray-500 border, cream-250 label, red-500 icon
      - first/last items use 8px outer corner radius

## App content surfaces (signed-in app)
- App pages render content below the 64px header inside rounded surface containers.
- Shared surface geometry:
  - no top margin below header (surfaces start directly under header)
  - outer spacing from viewport edges (left/right/bottom): 24px
  - split gap between main and aside surfaces: 24px
  - border radius: 24px
  - internal padding for main and aside content: 32px
- Pages without aside:
  - single full-width `main` surface (`gray-800`) within the 24px outer spacing.
- Split pages with aside (data source settings, query editor, data source setup):
  - `main` + `aside` render in a two-column split below header.
  - split layout fills available viewport height under header.
  - `aside` no longer participates in header layout; it sits entirely below header.
- Workspace chat split surface (`/app/workspaces/:id`):
  - history and conversation render as sibling surfaces (not nested).
  - desktop open state uses `260px + 1fr` columns with a 24px inter-surface gap.
  - both surfaces use 32px internal padding and 24px radius.
  - mobile (`<=760px`) history opens as overlay and collapses after thread selection.
- Workspace settings page (`/app/workspaces/:id/workspace-settings`):
  - treated as a main-surface page (not an aside-style panel layout).

## Workspace and data-source cards
- Workspace list cards and data-source list cards are full-width within their surface container.
- Card visual treatment:
  - background: `gray-850`
  - default border: `gray-700`
  - hover border: `gray-600`
  - card radius: `16px`
- Stat tile visual treatment inside cards:
  - background: `gray-800`
  - radius: `12px`
  - spacing between tiles uses 24px columns and 16px rows.
- Responsive behavior:
  - `>=1024px`: detail column + stat tiles share row (desktop split favors details while reserving 3/5 width for stat region).
  - `<1024px`: details on first row, all stat tiles on the next row.
  - `<720px`: stat tiles stack vertically in a single column.

## Data source home and phase-1 create flow
- Datasource home renders connector-family sections only when that family currently has rows:
  - `External databases`
  - `First-party data capture`
- External database rows currently surface:
  - name
  - connector type
  - selected table count
  - related query count
- First-party capture rows currently surface:
  - name
  - total events
  - events this month
  - related query count
- Phase-1 datasource creation is a three-step flow:
  1. choose connector family
  2. enter datasource name + PostgreSQL connection details and validate
  3. choose allowed tables and finish creation
- Current phase-1 create support is PostgreSQL only.
- First-party capture and third-party library options are intentionally shown as coming soon in the new wizard/catalog UI.
- Phase-1 datasource wizard uses cached table discovery as an optimization, but keeps essential connection state recoverable across requests so the flow does not depend solely on cache availability.

## Page header CTA spacing
- On workspace and data-source pages, inline `[+ Create New]` links beside `h1` use `16px` left spacing from the heading.

## Form typography and shared controls
- Default form labels use `cream-250`, body-size text (`14px/24px`), and bold weight unless a design explicitly overrides them.
- Shared step indicators carry their own `24px` top and bottom margin; page-specific layouts should not stack extra spacing onto the component unless a design calls for it.
- Datasource wizard copy should follow approved designs directly and should not introduce extra helper or hint text beyond what the design includes.

## Workspace creation flow
1. Authenticated user creates workspace with a name.
2. Workspace record is created.
3. Creator gets `Member` row with owner role + accepted status.
4. If this is first workspace, user is sent to data source onboarding.

## Team invitation flow
Source: `WorkspaceInvitationService`

- If an invitation email already belongs to an existing sqlbook user, invitation flow must not overwrite that user’s stored first/last name.
- Chat-driven invites must preserve the same rule as the manual team invite flow.

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
- Workspace ownership transfer notification email: `WorkspaceMailer.workspace_owner_transferred` (sent when account-deletion flow reassigns workspace ownership)
- Sender defaults to `noreply@sqlbook.com` via `ApplicationMailer`.
- Internal links in mailers should always be generated from route helpers + env-driven host/protocol config.
- Full cross-domain email catalog and template mapping: `docs/EMAILS_MASTER_REF.md`.

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
