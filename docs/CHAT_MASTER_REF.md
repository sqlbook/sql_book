# Chat Master Reference

Last updated: 2026-03-07

## Purpose
Single source of truth for workspace chat architecture, scope, permissions, confirmation lifecycle, and localization rules.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`
- `docs/TRANSLATIONS_MASTER_REF.md`
- `docs/ENGINEERING_GUARDRAILS.md`

## Scope (v1)
- Chat is strictly workspace-scoped and rendered on `GET /app/workspaces/:id`.
- Chat can execute only workspace/team-management actions that already exist elsewhere in app UX.
- Explicitly out of scope in v1:
  - cross-workspace actions
  - workspace list/get/create via chat
  - data source, query, dashboard, billing/subscription/admin/super-admin actions
  - owner-role promotion via chat

## Data model
- `ChatThread` (`chat_threads`)
  - workspace-scoped container
  - supports future multi-thread UI
- `ChatMessage` (`chat_messages`)
  - role: `user`, `assistant`, `system`
  - status: `pending`, `completed`, `failed`
  - supports image attachments via Active Storage (`has_many_attached :images`)
- `ChatActionRequest` (`chat_action_requests`)
  - structured action proposal with payload
  - confirmation token + expiry
  - lifecycle status: pending confirmation / executed / canceled / forbidden / validation error / execution error

## HTTP interface
- `GET /app/workspaces/:workspace_id/chat/messages`
- `POST /app/workspaces/:workspace_id/chat/messages`
- `POST /app/workspaces/:workspace_id/chat/actions/:id/confirm`
- `POST /app/workspaces/:workspace_id/chat/actions/:id/cancel`

## Action contract
Planner/executor payload contract includes:
- `action_type`
- structured `payload`
- `workspace_id`
- `thread_id`
- `message_id`

Executor result statuses:
- `requires_confirmation`
- `executed`
- `forbidden`
- `validation_error`
- `execution_error`

## Allowlist and denylist
Allowed action types:
- `workspace.update_name`
- `workspace.delete`
- `member.list`
- `member.invite`
- `member.resend_invite`
- `member.update_role`
- `member.remove`

Blocked prefixes:
- `workspace.list`
- `workspace.get`
- `workspace.create`
- `datasource.*`
- `query.*`
- `dashboard.*`
- `billing.*`
- `subscription.*`
- `admin.*`
- `super_admin.*`

## Authorization and scope enforcement
- Chat authorization is server-side only (`Chat::Policy` + `Chat::ActionExecutor`).
- Role and outrank rules mirror workspace team-management permissions.
- `workspace.delete` is owner-only.
- `member.invite` / `member.update_role` restrict target roles to non-owner editable roles.
- Scope checks reject payloads that do not belong to the current workspace/thread/message.

## Confirmation lifecycle
- All mutating actions require explicit inline confirmation.
- Pending confirmation requests have expiry (`15 minutes`).
- Confirm endpoint validates:
  - request is pending
  - token is valid
  - token is not expired
- Cancel endpoint marks pending requests canceled and appends assistant confirmation text.

## Attachment behavior (v1)
- Accepted MIME types:
  - `image/png`
  - `image/jpeg`
  - `image/webp`
  - `image/gif`
- Limits:
  - max `6` images per message
  - max `25MB` per image
- Validation occurs in both controller boundary and model validation.
- Planner includes attachment context for tool selection and can inline a bounded subset of images for multimodal reasoning.

## Workspace delete behavior in chat
- Confirmed `workspace.delete` action reuses `WorkspaceDeletionService`.
- Executor returns `redirect_path: /app/workspaces`.
- Existing deletion side-effects remain authoritative (toast + notification behavior).

## Localization and copy rules
- All deterministic chat copy must use locale keys:
  - empty-state UI copy
  - composer helper/aria text
  - confirmation card labels
  - status rows
  - non-LLM planner fallback copy
  - executor success/error copy
  - controller validation copy
  - client-side validation/fallback errors
- LLM free-form responses are dynamic and not locale-key managed.
- Current supported locales: `en`, `es`.
- When adding chat copy:
  1. check for existing reusable keys (`common.actions.*`) first
  2. add missing keys under `app.workspaces.chat.*`
  3. add both `en` and `es` entries in the same change
  4. verify via request spec with a non-default locale

## Testing baseline
- Policy tests for allowlist/blocked namespaces and role checks.
- Request specs for:
  - message creation and rendering
  - confirmation/cancel lifecycle
  - attachment validations (type/count/size)
  - localized copy behavior for Spanish locale
- Integration behavior for workspace deletion redirect and action status handling.
