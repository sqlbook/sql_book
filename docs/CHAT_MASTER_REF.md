# Chat Master Reference

Last updated: 2026-03-22

## Purpose
Single source of truth for workspace chat architecture, scope, permissions, confirmation lifecycle, API contracts, and localization rules.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/QUERIES_MASTER_REF.md`
- `docs/DATA_SOURCES_MASTER_REF.md`
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
- Chat can execute workspace/team-management actions, the phase-1 datasource-management actions, saved-query list/save/update/rename/delete actions, and read-only single-datasource query assistance that already exists elsewhere in app UX/API.
- Explicitly out of scope in v1:
  - cross-workspace actions
  - workspace list/get/create via chat
  - datasource update/delete/reconfigure actions beyond the phase-1 flow
  - query-management actions beyond `query.list`, `query.run`, `query.save`, `query.update`, `query.rename`, and `query.delete`
  - dashboard, billing/subscription/admin/super-admin actions
  - owner-role promotion via chat

## Core architecture
- Turn orchestration entrypoint: `Chat::TurnOrchestrator`
  - controller-thin boundary for each chat submission
  - owns turn context assembly, intent reconciliation, preflight, confirmation policy, execution, and final outcome rendering
- LLM/runtime layer:
  - `Chat::RuntimeService` handles structured intent classification and optional read-result phrasing
  - single-model structured-output decision path
  - planner fallback is used only when `OPENAI_API_KEY` is unavailable
  - if model returns non-JSON text, runtime uses that assistant text instead of collapsing to generic capability copy
  - supports multimodal image context (bounded inline subset)
  - uses Responses API `json_schema` structured output; dynamic tool arguments/payloads are serialized as JSON strings and parsed server-side to satisfy strict schema validation
- Context/state layer:
  - `Chat::ContextSnapshotBuilder`
  - `Chat::ContextSnapshot`
  - `Chat::ConversationContextResolver`
  - rebuilds each turn from recent transcript plus structured recent action context, rather than relying on parallel LLM-authored memory documents
- Intent reconciliation layer:
  - `Chat::IntentReconciler`
  - explicit current-turn instructions override stale or incorrect model payload fields before execution
  - current DB/member resolution overrides stale conversational guesses
- Shared tooling foundation:
  - `Tooling::Registry`
  - `Tooling::WorkspaceTeamRegistry`
  - `Tooling::WorkspaceTeamHandlers`
  - `Tooling::WorkspaceDataSourceRegistry`
  - `Tooling::WorkspaceDataSourceHandlers`
  - `Tooling::WorkspaceQueryRegistry`
  - `Tooling::WorkspaceQueryHandlers`
- Server-authoritative policy/execution:
  - `Chat::Policy` for role/scope checks
  - `Chat::ActionExecutor` for normalized execution statuses
  - `Chat::ExecutionTruthReconciler` for post-write DB refresh before final reply composition
  - `Chat::ActionRequestLifecycle` for action fingerprint / attempt lifecycle handling
  - `Chat::ResponseComposer` for localized fallback and confirmation copy when the app must own the wording

## Data model
- `ChatThread` (`chat_threads`)
  - workspace-scoped conversation container
  - supports multi-thread history and future thread switching UX
- `ChatMessage` (`chat_messages`)
  - role: `user`, `assistant`, `system`
  - status: `pending`, `completed`, `failed`
  - supports image attachments via Active Storage (`has_many_attached :images`)
  - assistant query-run messages may carry a structured `metadata.query_card` payload for app-rendered query UI blocks
- `ChatQueryReference` (`chat_query_references`)
  - durable per-thread query reference model owned by the app, not the LLM
  - stores query question, SQL, datasource, current name, prior aliases, lightweight result metadata, and optional `saved_query_id`
  - thread-only queries stay in `chat_query_references` with `saved_query_id = nil`
  - queries that were also saved to the shared query library keep their thread-local reference and attach `saved_query_id`
- `ChatActionRequest` (`chat_action_requests`)
  - structured action proposal / execution record with payload
  - confirmation token + expiry
  - lifecycle status: pending confirmation / executed / canceled / forbidden / validation error / execution error
  - `action_fingerprint`: stable semantic identity for the action within a thread
  - `idempotency_key`: per-attempt identity anchored to the source user message
  - `source_message_id`: the user turn that created the attempt
  - `superseded_at`: stale pending confirmations are marked superseded instead of remaining actionable

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
- `GET /api/v1/workspaces/:workspace_id/data-sources`
- `POST /api/v1/workspaces/:workspace_id/data-sources/validate-connection`
- `POST /api/v1/workspaces/:workspace_id/data-sources`
- `GET /api/v1/workspaces/:workspace_id/queries`
- `POST /api/v1/workspaces/:workspace_id/queries/run`
- `POST /api/v1/workspaces/:workspace_id/queries`
- `PATCH /api/v1/workspaces/:workspace_id/queries/:id`
- `DELETE /api/v1/workspaces/:workspace_id/queries/:id`

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
- `datasource.list`
- `datasource.validate_connection`
- `datasource.create`
- `query.list`
- `query.run`
- `query.save`
- `query.update`
- `query.rename`
- `query.delete`

Blocked prefixes:
- `workspace.list`
- `workspace.get`
- `workspace.create`
- `query.*` except `query.list`, `query.run`, `query.save`, `query.update`, `query.rename`, and `query.delete`
- `dashboard.*`
- `billing.*`
- `subscription.*`
- `admin.*`
- `super_admin.*`

Datasource namespace note:
- only `datasource.list`, `datasource.validate_connection`, and `datasource.create` are currently allowlisted
- all other datasource actions remain out of scope until explicitly added to the tool registry and policy layer

## Risk and confirmation policy
Read actions (`confirmation_mode: none`):
- `member.list`
- `datasource.list`
- `query.list`
- `query.run`

Auto-run writes (no confirmation):
- `workspace.update_name`
- `member.invite`
- `member.resend_invite`
- `member.update_role`
- `datasource.validate_connection`
- `datasource.create`
- `query.save`
- `query.rename`

High-risk writes (inline confirmation required):
- `workspace.delete`
- `member.remove`
- `query.delete`

## Required action fields (v1)
- `workspace.update_name`: `name`
- `member.invite`: `first_name`, `last_name`, `email`, `role`
- `member.resend_invite`: `email` or `member_id` or `full_name`
- `member.update_role`: (`email` or `member_id` or `full_name`) + `role`
- `member.remove`: `email` or `member_id` or `full_name`
- `datasource.validate_connection`: `host`, `database_name`, `username`, `password`
- `datasource.create`: `name`, `host`, `database_name`, `username`, `password`, `selected_tables`
- `query.run`: `question`
- Raw SQL messages beginning with `SELECT` or `WITH` should be treated as `query.run` immediately, even in threads that already contain saved-query or query-library context.
- Successful `query.run` turns should render as a structured chat query card rather than plain markdown SQL/results:
  - the chat card shows `Query` and `Results` drawers
  - initial state is `Query` closed and `Results` open
  - unsaved query cards show `Save Query` and `Open in query editor`
  - saved query cards remove `Save Query`
  - refinement cards based on a saved query show `Save Changes`, `Save as new`, and `Open in query library`
- `Open in query editor` from chat should open a prefilled unsaved draft view; it should not persist a draft query record until the user explicitly saves.
- `query.list`: no required fields
- `query.save`: `sql` + (`data_source_id` or `data_source_name`); `name` optional
- `query.update`: `query_id`, `sql` or `name` (or both)
- `query.rename`: `query_id`, `name`
- `query.delete`: `query_id`
- When `query.save` has no explicit name, chat should generate a concise title from the SQL/current query context instead of reusing a long conversational prompt or a generic analytic question like "How many users do I have?".
- Generated saved-query names should incorporate meaningful filters when they materially define the query (for example letter/name filters) rather than collapsing to a generic title like `User count` or `User names and email addresses`.
- `query.save` should not create an exact duplicate saved query in the same datasource; the app should return the existing saved query instead.
- If an auto-generated `query.save` name collides with a different saved query in the workspace, chat should pause and ask whether to keep that generated name or choose another, rather than silently saving with the colliding name.
- SQL-first chat threads should also get a human-readable generated title derived from the query intent instead of using the raw SQL statement as the thread title.
- Conversational rename follow-ups such as `rename it to DB User Count` or `Yes please` after the assistant offers a specific rename should stay in `query.rename`, not fall back to `query.run` or `query.list`.
- Conversational save follow-ups such as `save that`, `Could you save that for me?`, `update that query to this`, and `the first one` should resolve from thread-local query context before any scope-limited capability fallback is considered.
- Natural quoted rename phrasing such as `rename it 'User Count [Test]' please` should also stay in `query.rename`, even without the word `to`.
- If chat has already inferred the target rename name and then shows a saved-query list, a follow-up like `the first one` should still complete the rename in query context.
- Saved-query names rendered in chat list/save/rename responses should be internal links to the query page, using muted app link styling rather than bright external-link styling.
- Query continuity should resolve against persisted thread-local query references first, then legacy fallback state, rather than assuming only one recent query exists in the thread.
- Query continuity should preserve both thread-local drafts and saved-library links:
  - unsaved drafts remain thread-only references
  - saved queries attach to those references via `saved_query_id`
  - refinements can point back to the saved query they are iterating on
- When the latest draft is an obvious refinement of the currently discussed saved query, `save that` should update the saved query in place.
- When the latest draft has materially drifted from the current saved query, chat should ask whether to update+rename the existing saved query or save a new one.
- Combined update requests such as `update the User count [2] query to this, and rename it to User Count by SA Status` should resolve to one `query.update` action with both SQL and name.
- Delete confirmations for saved queries must be bound to an immutable `query_id` + `query_name` payload and the confirmation card/copy should name the specific query being deleted.
- For `READ_ONLY` members, ambiguous `users` clarifications should not imply that a database query is runnable; the clarification copy should surface the role limit up front instead of over-promising and only denying it on the next turn.

## Authorization and scope enforcement
- Authorization is server-side only (`Chat::Policy` + `Chat::ActionExecutor`).
- Role and outrank rules mirror workspace team-management permissions.
- `workspace.delete` is owner-only.
- `member.invite` / `member.update_role` restrict target roles to editable non-owner roles.
- `member.list` is visible only to workspace `OWNER` and `ADMIN` roles.
- `datasource.list` is visible/executable to workspace `OWNER`, `ADMIN`, and `USER` roles.
- `datasource.validate_connection` and `datasource.create` are visible/executable only to workspace `OWNER` and `ADMIN` roles.
- datasource phase-1 chat scope is limited to:
  - listing workspace datasources
  - validating PostgreSQL connection details
  - creating a PostgreSQL datasource with selected tables
- `query.list` is available to all accepted workspace roles.
- `query.run` is available to workspace `OWNER`, `ADMIN`, and `USER` roles, and denied for `READ_ONLY`.
- `query.save` is available to workspace `OWNER`, `ADMIN`, and `USER` roles, and denied for `READ_ONLY`.
- `query.update` is available to workspace `OWNER`, `ADMIN`, and `USER` roles, and denied for `READ_ONLY`.
- `query.rename` is available to workspace `OWNER`, `ADMIN`, and `USER` roles, and denied for `READ_ONLY`.
- `query.delete` is available to workspace `OWNER`, `ADMIN`, and `USER` roles when that role can delete the specific saved query; it is denied for `READ_ONLY`.
- Query chat scope is limited to read-only execution against one connected datasource at a time.
- Query-library chat scope in v1 includes:
  - listing saved queries in the current workspace
  - saving the most recently executed query into the query library
  - renaming saved queries in the current workspace
  - deleting saved queries from the current workspace with confirmation
- Query reference continuity rules:
  - `query.run` should create or refresh a thread-local query reference
  - `query.save` should attach the saved query id to the matching thread reference instead of replacing the thread-local record
  - `query.rename` should update the current name and preserve prior names as aliases on the same thread reference
  - `query.delete` should remove the saved-library link but keep the thread-local reference so later follow-ups in the thread still have context
- Saved-query provenance rules:
  - query settings may show a `Chat source` link when the saved query originated from chat and the current viewer can still access that thread
  - `Chat source` must never expose another member's private chat thread
  - archived threads remain valid provenance targets; deleted threads simply remove the link
- Saved-query names rendered in chat responses should be internal links that open in a new tab, so users can inspect the saved query without losing chat position.
- If a user opens an old saved-query link from chat after that query has been deleted, the product should redirect them to Query Library and show an error toast explaining that the query no longer exists.
- If multiple datasources or tables plausibly match a query question, chat must ask a clarifying follow-up before running SQL.
- Scope checks reject payloads that do not belong to the current workspace/thread/message.
- Permission-denied replies should say which workspace roles can perform the requested action instead of only returning a flat refusal.
- Execution/preflight wording should be composed separately from the executor so chat can vary phrasing naturally and avoid repeating the same template back-to-back.
- Only destructive chat writes require confirmation in v1 (`workspace.delete`, `member.remove`, `query.delete`). `member.update_role`, `query.save`, and `query.rename` auto-execute after preflight passes.

## Runtime decision flow
1. User message is persisted immediately.
2. Runtime rebuilds turn context from:
   - recent transcript (`user` + `assistant` turns, oldest -> newest)
   - pending confirmation state
   - staged datasource setup state
   - staged query clarification state
   - recent structured query references (most relevant thread-local query records with aliases/result metadata)
   - legacy recent query state fallback during transition
   - connected datasource inventory
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
8. `Chat::ActionRequestLifecycle` decides whether to:
   - refresh an active pending confirmation
   - supersede stale pending confirmations
   - create a fresh write attempt for a new user turn
9. Runtime should prefer model-authored user-facing execution replies from structured tool results, in the actor's locale, for ordinary acknowledgements and follow-up prose.
10. `Chat::ResponseComposer` remains the fallback/confirmation layer for product-owned wording such as confirm prompts, no-LLM fallbacks, and fixed permission/validation copy.
11. If model planning fails while API key is present, runtime returns localized retry copy (`app.workspaces.chat.messages.runtime_retry`) rather than generic capability text.
12. Clearly off-scope or general-purpose questions should be intercepted before tool planning and answered with a scope-limited help message rather than being forced through stale action context.
13. Datasource setup should collect missing connection information in sensible stages instead of dumping every possible field request into one turn.
14. Query follow-ups about current mutable datasource/member facts should verify live workspace state before asserting them.
15. Active query clarification and obvious query-scope follow-ups must take precedence over stale datasource-setup state in the same thread.
16. Successful in-scope replies may end with one short natural next step (for example saving a query, refining a result, or asking one relevant follow-up), but chat should do this sparingly and avoid repetitive stock sign-offs.
17. Permission denials and other variant-backed assistant replies must always collapse to one localized user-facing sentence; raw variant arrays must never leak into the chat stream.

## Context assembly rules
- Chat should stay conversational, but server state remains authoritative.
- Do not introduce shadow "memory docs" or parallel LLM-maintained records just to preserve context.
- Preferred turn context ingredients:
  - recent raw transcript
  - structured recent tool/action results
  - connected datasource inventory, including selected-table previews
  - staged datasource setup state
  - staged query clarification state
  - refreshed current workspace state for the most recently referenced member when a follow-up asks who/status/confirmation
  - current pending confirmation / unresolved required fields
  - compact summaries only if threads become too long for direct transcript slices
- Structured recent action results are context, not truth. Before asserting a mutable workspace fact (for example a member's current role or invite status), chat should verify the current state against live workspace data.
- Recent action result context should support follow-ups such as:
  - "invite him back" after a remove action
  - "what role did you add him as?" after an invite action
  - "have they accepted?" or "which user are we talking about?" after an invite is later accepted in another session
- Recent query context should support follow-ups such as:
  - "save this query"
  - "save that for me"
  - "save it as Active users by day"
  - "show my query library"
  - "rename that query to Active users by day"
  - "delete that saved query"
  - "could you change it to User Count?" after saving or listing a recent query
  - explicit rename requests that quote both the current saved-query name and the new name, even when the user ends the sentence with punctuation
  - short elliptical refinements such as "What about the letter i?" when the user is clearly continuing the most recent query
- Datasource setup follow-ups should support:
  - friendly staged answers like "Call it Warehouse DB"
  - freeform connection-detail replies such as "my database name is JOHNNY and the type is PostgreSQL"
  - table-selection follow-ups such as "Use public.users"
- Query clarification follow-ups should support:
  - datasource disambiguation such as "Use Warehouse DB"
  - table disambiguation when multiple candidate tables match the question
  - scope clarification replies such as "I mean in my connected database"
  - branch-preserving follow-ups such as "And my users?" after the user first answered the workspace-members branch
- Meta capability replies should stay high-level and category-based (for example team management, data sources, queries, workspace settings) rather than dumping a long action-by-action list unless the user asks for more detail in one category.
  - schema-guidance follow-ups such as "Can you tell from the schema?" without falling back to generic datasource listing
- Questions such as "Who are my users?" should be treated as query-like when workspace datasource context indicates the user may mean database records.
- If exactly one active datasource exists and the likely table is clear from schema/name/column hints, chat should resolve that datasource automatically instead of asking for a datasource id or name again.
- Referential member follow-ups such as "what are their names and details?" should stay in scope when a recent member/team result is present, even if the message does not repeat words like `member` or `team`.
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
- Datasource tool payloads should stay contract-shaped and deterministic so chat can safely hand connection metadata and selected tables to the server-authoritative handlers.

## Action lifecycle and idempotency behavior
- `action_fingerprint` identifies the semantic action within a thread.
- `idempotency_key` identifies the specific attempt created by one user turn.
- Same semantic action on a new turn creates a fresh attempt with a new `idempotency_key`.
- Only still-active pending confirmations may be refreshed/reused.
- Expired or superseded pending confirmations must never be accepted.
- Completed writes are historical context only; they must not block future attempts or replay as if they were current execution.
- For member role updates and similar member-targeted writes, explicit instructions in the current user message (for example `Promote Bob Smith to Admin`) override stale or incorrect model payload fields before execution.
- Executed write summaries should not feed stale human-readable success strings back into planning as if they were the current source of truth; current member/workspace snapshots are authoritative for factual follow-ups.
- Prevents duplicate side effects on retries or repeated Enter submits.
- Requires DB migrations:
  - `20260309102000_add_idempotency_key_to_chat_action_requests`
  - `20260316143000_refactor_chat_action_request_lifecycle`

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
- If a repeated high-risk request hits an old pending confirmation from a previous turn, the stale request should be superseded or refreshed safely rather than surfacing a `422` uniqueness error or reusing an expired button state.
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
- Natural role replies such as `he can be an Admin` should also be treated as explicit role instructions.
- Invite/setup replies should use neutral phrasing for people unless the user explicitly provided pronouns; chat should not assume gender.
- Chat must not silently assume a role when the user has not provided one.
- If the invite email belongs to an existing sqlbook user, chat invite execution must not overwrite that user’s stored first/last name; only workspace membership/invitation state should change.

## Recent-member continuity rules
- Follow-up questions about the most recently invited/removed/updated member should resolve against recent structured action context first.
- When possible, chat should refresh that recent member against current workspace membership state before answering status/identity/clarification follow-ups.
- This is how prompts like `Have they accepted?`, `Which user are we talking about?`, and `Are you sure?` stay grounded even if membership changed in another browser session.

## Thread/sidebar UX behavior
- Sidebar width is fixed at `260px` on desktop.
- Sidebar panel padding is `24px`.
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
- If there are no persisted threads, `No chats yet` should render at the top of the thread-list region directly under search, not pinned to the bottom of the sidebar.
- Thread and message fetch/update routes are scoped by `workspace_id + current_user` to prevent cross-member history leakage.

## Message stream UX behavior
- User messages render immediately on submit (optimistic append) before runtime response returns.
- The composer input row should use the same field chrome as the chat-history search field for default, hover, and focus states.
- In existing threads, the composer should restore focus after message submission so users can continue typing without manually clicking back into the field.
- Message timestamps are intentionally hidden in chat stream UI.
- System `Thinking` rows render animated trailing ellipsis only while pending/optimistic.
- Transient runtime status rows are not durable conversation content and should disappear once the assistant reply/result has rendered.
- Sticky composer area includes an opaque mask so older messages are hidden until scrolled above the composer.
- Assistant content now supports sanitized markdown rendering for lists, tables, emphasis, links, blockquotes, and code blocks.
- Markdown is rendered server-side and sanitized before output; raw HTML from model output is not trusted.
- Runtime result rendering must preserve line breaks and paragraph spacing; collapsing all whitespace before markdown render breaks lists and tables into plain paragraphs.
- Same-thread non-confirmation chat responses (`executed`, `forbidden`, `validation_error`, `execution_error`, `canceled`) should render inline from the JSON response without requiring a full Turbo page revisit, so successful low-risk writes always produce a visible assistant acknowledgement.
- Attachment validation/error areas should collapse completely when empty; they must not reserve vertical space below the composer when there is no content to show.

## Empty-state UX behavior
- Empty-state quokka image renders at `50px` wide.
- Spacing:
  - `32px` from image to heading
  - `32px` from heading to suggestion chips
  - `48px` from suggestion chips to composer
  - `8px` from composer to helper text
- Suggestion chips should remain on one row until the viewport is narrow enough to require wrapping.
- User message bubble padding is `8px 16px`.

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
- Product-owned chat copy must use locale keys:
  - empty-state UI copy
  - composer helper/aria text
  - confirmation card labels
  - status rows
  - planner fallback copy
  - runtime retry copy for planning failures
  - executor/API validation and hard permission/constraint copy
  - client-side validation/fallback errors
- Ordinary assistant acknowledgements and naturalized tool-result phrasing should be model-authored in the user's locale from structured tool output rather than expanded into per-phrase locale keys.
- Deterministic follow-up prompts for missing required fields must use locale keys.
- Current supported locales: `en`, `es`.
- When adding chat copy:
  1. check reusable keys first (`common.*`, existing workspace/team labels)
  2. add missing keys under `app.workspaces.chat.*` only when the app itself must own the wording
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
