# Engineering Guardrails

## Query Execution Safety
- All user-generated SQL must run with read-only DB permissions.
- Enforce workspace/tenant scoping server-side, not only in prompts/UI.
- Block DDL/DML and unsafe SQL statements.
- Apply statement timeout and max returned rows.
- Log prompt, generated SQL, execution metadata, and errors for auditability.

## LLM SQL Assistant
- LLM output is a draft, not trusted execution input.
- Validate and sanitize generated SQL before execution.
- Show generated SQL to users before run.
- Preserve explicit user control to edit SQL manually.

## Connector Ingestion
- Use connector-specific execution strategy:
  - SQL database connectors default to live read-only querying in v1.
  - API/SaaS connectors can use selective sync/materialization when live-query is impractical.
- Use incremental sync + webhooks for sync-based connectors when providers support them.
- Track sync status, retries, and dead-letter failures.
- Keep provider credentials encrypted and scoped minimally.

## Ops Baseline
- Use separate staging and production environments.
- Keep secrets out of git; rotate periodically.
- Add backup/restore runbook for Postgres before launch.
- Add uptime + error monitoring before accepting production users.

## UI Messaging Safety
- For toast actions that link inside the app, prefer `path` (for example `/app/workspaces`) instead of absolute URLs.
- If an internal absolute `https://*.sqlbook.com/...` URL is provided, normalize it to a relative path before rendering.
- Reserve absolute URLs for genuinely external destinations (for example docs/help center).
- Toast locale copy is plain text; do not use HTML entities like `&apos;` in toast translation strings.
- See `docs/TOASTS_MASTER_REF.md` for toast-specific copy/encoding/interpolation rules.
- For workspace chat, locale keys are for product UI chrome, deterministic non-LLM fallback, confirmations, and client-side validation only.
- Do not introduce new chat-localized business prose when a structured result code plus typed data can carry the truth.
- Normal assistant acknowledgements, summaries, and tool-result phrasing should be model-authored from structured execution truth.

## Chat Context Guardrails
- Keep chat continuity server-owned and provider-agnostic.
- Prefer structured app context over longer transcript when improving follow-up continuity.
- Do not introduce domain-specific ad hoc chat memory/state if the behavior can be represented by the shared continuity contract.
- The shared contract is:
  - `active_focus`: the single most relevant current object/flow
  - `pending_follow_up`: the single unresolved next step most likely being answered
- Prompt/context work must preserve stable ordered sections rather than mixed free-form context blobs.
- New chat-supported domains must extend the shared continuity contract by defining:
  - focus derivation
  - pending follow-up derivation
  - concise app-authored task summaries
  - prompt-section placement
- Do not make provider/model-specific memory features the source of truth for:
  - object identity
  - permissions
  - confirmations
  - lifecycle state
- If continuity work touches prompting, runtime, planner, or context builders, update `docs/CHAT_MASTER_REF.md` in the same change.

## Chat Translation Guardrails
- The app owns structured truth; the model owns ordinary wording.
- New chat-supported domains must define structured result codes and typed payloads before adding conversational copy.
- Keep API/tool result codes English-first and provider-agnostic.
- Rails locales are not the primary content system for assistant prose.
- Do not build heuristic SQL naming/parsing layers into the primary saved-query naming path for chat when the model can name the query from full context.
- If model-based saved-query naming is unavailable, ask the user for a name instead of expanding heuristic fallback logic to cover more query-intent cases.
- If a chat change adds or changes locale-backed copy, run:
  - `bundle exec rake chat:audit_copy_surface`
  - `bundle exec rake chat:enforce_copy_contract`
- Do not reintroduce deprecated chat locale namespaces such as executor/response-variant trees for business outcomes.

## API Docs Contract Safety
- Treat `config/openapi/v1.json` as a maintained contract, not optional documentation.
- Any change to documented API behavior must update the OpenAPI document in the same change.
- API docs must stay usable for both humans and LLM/tool consumers:
  - short summaries for navigation
  - explicit descriptions for scope/risk/behavior
  - typed request and response schemas
  - concrete examples for success and error paths
- Keep docs environment-safe:
  - no hardcoded staging/production hostnames in the spec
  - prefer relative server URLs and Scalar environment variables
- Validate docs changes with `bundle exec rake openapi:validate`.
- See `docs/API_MASTER_REF.md` for the full authoring and maintenance workflow.
