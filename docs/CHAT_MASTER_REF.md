# Chat Master Reference

Last updated: 2026-03-09

## Purpose
Single source of truth for workspace chat architecture, scope, permissions, confirmation lifecycle, API contracts, and localization rules.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`
- `docs/TRANSLATIONS_MASTER_REF.md`
- `docs/ENGINEERING_GUARDRAILS.md`
- `docs/ENV_VARS.md`
- `docs/RENDER_MASTER_REF.md`

## Runtime configuration
- `OPENAI_API_KEY` (required for LLM-backed chat runtime and thread title generation)
- `OPENAI_CHAT_MODEL` (optional, defaults to `gpt-5-mini`)
- `OPENAI_RESPONSES_ENDPOINT` (optional, defaults to `https://api.openai.com/v1/responses`)

## Scope (v1)
- Chat is strictly workspace-scoped and rendered on `GET /app/workspaces/:id`.
- Chat can execute only workspace/team-management actions that already exist elsewhere in app UX.
- Explicitly out of scope in v1:
  - cross-workspace actions
  - workspace list/get/create via chat
  - data source, query, dashboard, billing/subscription/admin/super-admin actions
  - owner-role promotion via chat

## Core architecture
- Runtime orchestrator: `Chat::RuntimeService`
  - single-model structured-output decision path
  - optional planner fallback only if model output is missing/invalid
  - supports multimodal image context (bounded inline subset)
- Shared tooling foundation:
  - `Tooling::Registry`
  - `Tooling::WorkspaceTeamRegistry`
  - `Tooling::WorkspaceTeamHandlers`
- Server-authoritative policy/execution:
  - `Chat::Policy` for role/scope checks
  - `Chat::ActionExecutor` for normalized execution statuses
- Schema-drift safety:
  - if `chat_action_requests.idempotency_key` is not present yet, write idempotency dedupe is skipped to prevent request-time 500s during partial deploy/migration windows

## Data model
- `ChatThread` (`chat_threads`)
  - workspace-scoped conversation container
  - supports multi-thread history and future thread switching UX
- `ChatMessage` (`chat_messages`)
  - role: `user`, `assistant`, `system`
  - status: `pending`, `completed`, `failed`
  - supports image attachments via Active Storage (`has_many_attached :images`)
- `ChatActionRequest` (`chat_action_requests`)
  - structured action proposal with payload
  - confirmation token + expiry
  - lifecycle status: pending confirmation / executed / canceled / forbidden / validation error / execution error
  - idempotency key for deduplicating repeated write requests

## HTTP interfaces
App routes:
- `GET /app/workspaces/:workspace_id/chat/threads`
- `POST /app/workspaces/:workspace_id/chat/threads`
- `PATCH /app/workspaces/:workspace_id/chat/threads/:id`
- `DELETE /app/workspaces/:workspace_id/chat/threads/:id`
- `GET /app/workspaces/:workspace_id/chat/messages`
- `POST /app/workspaces/:workspace_id/chat/messages`
- `POST /app/workspaces/:workspace_id/chat/actions/:id/confirm`
- `POST /app/workspaces/:workspace_id/chat/actions/:id/cancel`

API v1 routes (internal-first, documented):
- `PATCH /api/v1/workspaces/:workspace_id`
- `DELETE /api/v1/workspaces/:workspace_id`
- `GET /api/v1/workspaces/:workspace_id/members`
- `POST /api/v1/workspaces/:workspace_id/members`
- `POST /api/v1/workspaces/:workspace_id/members/resend-invite`
- `PATCH /api/v1/workspaces/:workspace_id/members/:id/role`
- `DELETE /api/v1/workspaces/:workspace_id/members/:id`

Docs surface:
- `GET /dev/api`
- `GET /dev/api/openapi.json`

## Tool contract
Tool definition contract:
- `name`
- `description`
- `input_schema`
- `output_schema`
- `risk_level`
- `confirmation_mode`
- `handler`

Runtime action payload contract:
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

## Allowlist and blocked namespaces
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

## Risk and confirmation policy
Read actions (`confirmation_mode: none`):
- `member.list`

Low-risk writes (auto-run, no confirmation):
- `workspace.update_name`
- `member.invite`
- `member.resend_invite`

High-risk writes (inline confirmation required):
- `workspace.delete`
- `member.update_role`
- `member.remove`

## Required action fields (v1)
- `workspace.update_name`: `name`
- `member.invite`: `first_name`, `last_name`, `email` (role optional; defaults to `USER`)
- `member.resend_invite`: `email` or `member_id`
- `member.update_role`: (`email` or `member_id`) + `role`
- `member.remove`: `email` or `member_id`

## Authorization and scope enforcement
- Authorization is server-side only (`Chat::Policy` + `Chat::ActionExecutor`).
- Role and outrank rules mirror workspace team-management permissions.
- `workspace.delete` is owner-only.
- `member.invite` / `member.update_role` restrict target roles to editable non-owner roles.
- Scope checks reject payloads that do not belong to the current workspace/thread/message.

## Runtime decision flow
1. User message is persisted immediately.
2. Runtime returns structured decision:
   - `assistant_message`
   - `tool_calls[]` (`tool_name`, `arguments`)
   - `missing_information[]`
   - `finalize_without_tools`
3. If `missing_information` exists, assistant asks follow-up (no execution).
4. If tool call is high-risk write, create confirmation card.
5. If tool call is read or low-risk write, execute immediately via `Chat::ActionExecutor`.
6. For read tools, runtime may produce a naturalized response from tool output, with deterministic fallback text if needed.

## Idempotency behavior (writes)
- Write actions use deterministic idempotency keys scoped by workspace/thread/actor/tool/payload.
- Duplicate submissions inside the idempotency window reuse prior request state/result.
- Prevents duplicate side effects on retries or repeated Enter submits.
- Requires DB migration `20260309102000_add_idempotency_key_to_chat_action_requests`.
- If that migration is not applied yet in an environment, writes still execute but dedupe is skipped until migration is applied.

## Confirmation lifecycle
- Confirmation required only for high-risk writes.
- Confirm endpoint validates:
  - request is pending
  - token is valid
  - token is not expired
- Cancel endpoint marks pending requests canceled and appends assistant confirmation text.
- Pending confirmation expiry: `15 minutes`.

## Thread/sidebar UX behavior
- Sidebar width is fixed at `260px` on desktop.
- Sidebar is closed by default only when a workspace has no persisted chat threads yet.
- Sidebar open/closed preference is stored in session storage per workspace and reused during the same browser session.
- On mobile (`<=760px`), sidebar opens as full chat-surface overlay and collapses after thread selection (or manual close).
- Sidebar toggle uses line icons only (`chat-sidebar-icon-fold` / `chat-sidebar-icon-unfold`), 16px.
- Toggle location:
  - open sidebar: fold toggle lives inside sidebar header
  - closed sidebar: unfold toggle lives at top-left of conversation surface
- "New chat" starts as a draft view and does not create/list a thread until first message submission.
- Thread title is generated from the first user message (LLM-first with deterministic fallback).
- Thread list supports local title search (filter activates at 2+ characters), inline rename, and archive/delete from row menu.

## Message stream UX behavior
- User messages render immediately on submit (optimistic append) before runtime response returns.
- Message timestamps are intentionally hidden in chat stream UI.
- System `Thinking` rows render with animated trailing ellipsis to indicate active work.
- Sticky composer area includes an opaque mask so older messages are hidden until scrolled above the composer.

## Attachment behavior (v1)
- Accepted MIME types:
  - `image/png`
  - `image/jpeg`
  - `image/webp`
  - `image/gif`
- Limits:
  - max `6` images per message
  - max `25MB` per image
- Validation occurs at controller and model boundaries.
- Runtime receives attachment context and can inline a bounded subset for multimodal reasoning.

## Workspace delete behavior in chat
- Confirmed `workspace.delete` reuses `WorkspaceDeletionService`.
- Executor returns `redirect_path: /app/workspaces`.
- Existing deletion side effects remain authoritative (toast + notification behavior).

## Localization and copy rules
- All deterministic chat copy must use locale keys:
  - empty-state UI copy
  - composer helper/aria text
  - confirmation card labels
  - status rows
  - planner fallback copy
  - executor/API validation and result copy
  - client-side validation/fallback errors
- LLM free-form responses are dynamic and are not locale-key managed.
- Deterministic follow-up prompts for missing required fields must use locale keys.
- Current supported locales: `en`, `es`.
- When adding chat copy:
  1. check reusable keys first (`common.*`, existing workspace/team labels)
  2. add missing keys under `app.workspaces.chat.*`
  3. add both `en` and `es` entries in the same change
  4. verify through request specs with non-default locale

## Testing baseline
- Policy tests for allowlist/blocked namespaces and role/scope checks.
- Tool registry tests for schema validation and normalized error handling.
- Runtime tests for structured parsing and fallback behavior.
- Request specs for:
  - message creation and rendering
  - confirmation/cancel lifecycle
  - attachment validations (type/count/size)
  - idempotency dedupe behavior
  - localized deterministic copy behavior (`es`)
- API docs checks:
  - `/dev/api` and `/dev/api/openapi.json` availability
  - OpenAPI contract validation task (`rake openapi:validate`)

## Component preview surface
- Route: `GET /app/chat-components`
- Purpose: visual QA page for chat component styling/states before final design sign-off.
