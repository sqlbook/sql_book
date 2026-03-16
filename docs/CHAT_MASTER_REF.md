# Chat Master Reference

Last updated: 2026-03-14

## Purpose
Single source of truth for workspace chat architecture, scope, permissions, confirmation lifecycle, API contracts, and localization rules.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`
- `docs/API_MASTER_REF.md`
- `docs/TRANSLATIONS_MASTER_REF.md`
- `docs/ENGINEERING_GUARDRAILS.md`
- `docs/ENV_VARS.md`
- `docs/RENDER_MASTER_REF.md`

## Runtime configuration
- `OPENAI_API_KEY` (required for LLM-backed chat runtime and thread title generation)
- `OPENAI_CHAT_MODEL` (defaults to `gpt-5-mini` if unset, but should be explicitly configured in deploy environments)
- `OPENAI_RESPONSES_ENDPOINT` (optional, defaults to `https://api.openai.com/v1/responses`)

## Scope (v1)
- Chat is strictly workspace-scoped and rendered on `GET /app/workspaces/:id`.
- Chat history is isolated per user within each workspace (a member can only access threads they created).
- Chat can execute only workspace/team-management actions that already exist elsewhere in app UX.
- Explicitly out of scope in v1:
  - cross-workspace actions
  - workspace list/get/create via chat
  - data source, query, dashboard, billing/subscription/admin/super-admin actions
  - owner-role promotion via chat

## Core architecture
- Runtime orchestrator: `Chat::RuntimeService`
  - single-model structured-output decision path
  - planner fallback is used only when `OPENAI_API_KEY` is unavailable
  - if model returns non-JSON text, runtime uses that assistant text instead of collapsing to generic capability copy
  - supports multimodal image context (bounded inline subset)
  - uses Responses API `json_schema` structured output; dynamic tool arguments/payloads are serialized as JSON strings and parsed server-side to satisfy strict schema validation
  - rebuilds each turn from recent transcript plus structured recent action context, rather than relying on parallel LLM-authored memory documents
- Shared tooling foundation:
  - `Tooling::Registry`
  - `Tooling::WorkspaceTeamRegistry`
  - `Tooling::WorkspaceTeamHandlers`
- Server-authoritative policy/execution:
  - `Chat::Policy` for role/scope checks
  - `Chat::ActionExecutor` for normalized execution statuses
  - `Chat::ResponseComposer` for final user-facing execution replies
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
- `member.invite`: `first_name`, `last_name`, `email`, `role`
- `member.resend_invite`: `email` or `member_id` or `full_name`
- `member.update_role`: (`email` or `member_id` or `full_name`) + `role`
- `member.remove`: `email` or `member_id` or `full_name`

## Authorization and scope enforcement
- Authorization is server-side only (`Chat::Policy` + `Chat::ActionExecutor`).
- Role and outrank rules mirror workspace team-management permissions.
- `workspace.delete` is owner-only.
- `member.invite` / `member.update_role` restrict target roles to editable non-owner roles.
- `member.list` is visible only to workspace `OWNER` and `ADMIN` roles.
- Scope checks reject payloads that do not belong to the current workspace/thread/message.
- Permission-denied replies should say which workspace roles can perform the requested action instead of only returning a flat refusal.
- Execution/preflight wording should be composed separately from the executor so chat can vary phrasing naturally and avoid repeating the same template back-to-back.

## Runtime decision flow
1. User message is persisted immediately.
2. Runtime rebuilds turn context from:
   - recent transcript (`user` + `assistant` turns, oldest -> newest)
   - pending confirmation state
   - structured recent action results persisted in assistant-message `metadata.result_data`
3. Runtime returns structured decision:
   - `assistant_message`
   - `tool_calls[]` (`tool_name`, `arguments`)
   - `missing_information[]`
   - `finalize_without_tools`
4. If `missing_information` exists, assistant asks follow-up (no execution).
5. Preflight policy/scope validation runs before any confirmation UI is created.
6. If tool call is high-risk write and preflight passes, create confirmation card.
7. If tool call is read or low-risk write, execute immediately via `Chat::ActionExecutor`.
8. `Chat::ResponseComposer` converts execution/preflight results into user-facing assistant copy using locale-backed variants and recent assistant history to reduce repetition.
9. For read tools, runtime may produce a naturalized response from tool output, with deterministic fallback text if needed.
10. If model planning fails while API key is present, runtime returns localized retry copy (`app.workspaces.chat.messages.runtime_retry`) rather than generic capability text.

## Context assembly rules
- Chat should stay conversational, but server state remains authoritative.
- Do not introduce shadow "memory docs" or parallel LLM-maintained records just to preserve context.
- Preferred turn context ingredients:
  - recent raw transcript
  - structured recent tool/action results
  - refreshed current workspace state for the most recently referenced member when a follow-up asks who/status/confirmation
  - current pending confirmation / unresolved required fields
  - compact summaries only if threads become too long for direct transcript slices
- Recent action result context should support follow-ups such as:
  - "invite him back" after a remove action
  - "what role did you add him as?" after an invite action
  - "have they accepted?" or "which user are we talking about?" after an invite is later accepted in another session
- Structured result data is persisted on assistant messages for both:
  - auto-executed actions
  - confirmed high-risk actions

## Responses API schema guardrail
- Chat runtime and planner both use strict Responses API `json_schema` output.
- Dynamic nested argument objects should not be modeled as open-ended nested objects in strict schemas.
- Current runtime/planner contract:
  - `Chat::RuntimeService::DECISION_SCHEMA -> tool_calls[].arguments` is a JSON string encoding an object
  - `Chat::PlannerService::PLAN_SCHEMA -> payload` is a JSON string encoding an object
- Runtime/planner parse those JSON strings back into hashes server-side before execution.
- If staging logs show `Invalid schema for response_format`, fix the schema contract first; changing prompts or models will not resolve that class of failure.

## Idempotency behavior (writes)
- Write actions use deterministic idempotency keys scoped by workspace/thread/actor/tool/payload.
- Duplicate submissions inside the idempotency window reuse prior request state/result.
- Prevents duplicate side effects on retries or repeated Enter submits.
- Requires DB migration `20260309102000_add_idempotency_key_to_chat_action_requests`.
- If that migration is not applied yet in an environment, writes still execute but dedupe is skipped until migration is applied.

## Confirmation lifecycle
- Confirmation required only for high-risk writes.
- High-risk actions must never render a confirmation card if preflight policy/scope validation already knows the actor cannot perform them.
- Users can confirm/cancel pending actions either:
  - via inline chat buttons
  - via explicit follow-up chat messages such as confirmation/cancellation replies
- Pending confirmation assistant messages should render inline `Confirm` / `Cancel` controls in the chat UI while the action remains pending.
- Stimulus inline action requests (`confirm`, `cancel`, thread delete/rename) must send Rails CSRF protection in both places:
  - `X-CSRF-Token` header from the page meta tag
  - `authenticity_token` field in ad-hoc `FormData` bodies
- If a repeated high-risk request hits an old pending confirmation with the same idempotency key, stale confirmations must be refreshed with a new token/expiry instead of surfacing a `422` uniqueness error or reusing an expired button state.
- High-risk member actions should resolve a uniquely named workspace member into a concrete pending action request so the confirmation card can render, rather than asking for free-text confirmation with no action request behind it.
- Confirm endpoint validates:
  - request is pending
  - token is valid
  - token is not expired
- Cancel endpoint marks pending requests canceled and appends assistant confirmation text.
- Pending confirmation expiry: `15 minutes`.

## Invite follow-up rules
- `member.invite` always requires `first_name`, `last_name`, `email`, and `role`.
- Invite follow-up prompts should ask for all currently missing invite fields in one message, not drip-feed one property per turn.
- Natural role replies such as `admin`, `I think admin`, or `make them admin` should be treated as explicit role instructions.
- Chat must not silently assume a role when the user has not provided one.
- If the invite email belongs to an existing sqlbook user, chat invite execution must not overwrite that user’s stored first/last name; only workspace membership/invitation state should change.

## Recent-member continuity rules
- Follow-up questions about the most recently invited/removed/updated member should resolve against recent structured action context first.
- When possible, chat should refresh that recent member against current workspace membership state before answering status/identity/clarification follow-ups.
- This is how prompts like `Have they accepted?`, `Which user are we talking about?`, and `Are you sure?` stay grounded even if membership changed in another browser session.

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
- Thread and message fetch/update routes are scoped by `workspace_id + current_user` to prevent cross-member history leakage.

## Message stream UX behavior
- User messages render immediately on submit (optimistic append) before runtime response returns.
- Message timestamps are intentionally hidden in chat stream UI.
- System `Thinking` rows render animated trailing ellipsis only while pending/optimistic.
- Transient status rows such as `Thinking`, `Checking permissions`, and `Done` should disappear once the assistant reply/result has rendered; they are not durable conversation content.
- Sticky composer area includes an opaque mask so older messages are hidden until scrolled above the composer.
- Assistant content now supports sanitized markdown rendering for lists, tables, emphasis, links, blockquotes, and code blocks.
- Markdown is rendered server-side and sanitized before output; raw HTML from model output is not trusted.
- Runtime result rendering must preserve line breaks and paragraph spacing; collapsing all whitespace before markdown render breaks lists and tables into plain paragraphs.

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
  - runtime retry copy for planning failures
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
