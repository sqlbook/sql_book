# API Master Reference

Last updated: 2026-03-21

## Purpose
Single source of truth for sqlbook's documented API surface, OpenAPI authoring rules, Scalar setup, and the maintenance workflow that keeps the docs useful for both humans and LLM/tool consumers.

Related references:
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/DATA_SOURCES_MASTER_REF.md`
- `docs/CHAT_MASTER_REF.md`
- `docs/ENGINEERING_GUARDRAILS.md`
- `docs/ENV_VARS.md`
- `docs/RENDER_MASTER_REF.md`

## Public docs surface
- `GET /dev/api`
  - public Scalar API reference UI
- `GET /dev/api/openapi.json`
  - public OpenAPI source document rendered by Scalar

Important:
- Docs are public.
- API execution remains auth-protected.
- Auth model today is session cookie auth (`_sqlbook_session`).

## Current documented API scope
The API reference should be treated as the documented surface for the app as it exists today, even though coverage is still being expanded over time.

Current OpenAPI coverage includes the workspace, team-management, datasource, and query contracts that are already exposed through product and chat flows:
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

Current datasource API scope:
- phase 1 is PostgreSQL-only for external database creation/validation
- routes are workspace-scoped and session-authenticated
- owner/admin only for datasource management actions
- the API is intentionally phrased so both engineers and the workspace chat/runtime can consume the same contract cleanly

Current query API scope:
- query-library list is available to all accepted workspace roles
- read-only query execution is available to `OWNER`, `ADMIN`, and `USER`
- query save is available to `OWNER`, `ADMIN`, and `USER`
- query rename is available to `OWNER`, `ADMIN`, and `USER`
- query delete is available to `OWNER`, `ADMIN`, and `USER` when that role can delete the specific saved query
- callers can send either a plain-language question or direct read-only SQL to the run endpoint
- save requests require SQL plus datasource identity; query name can be server-generated when omitted
- rename requests require a target query id and the new saved-query name
- delete requests require a target query id and should be treated as destructive
- saved query responses can include an optional `chat_source` object when the query originated from chat and the current requester can still access that private source thread
- chat continuity for queries is thread-local and server-owned via persisted query references; unsaved thread-only queries are not promoted into the shared query library unless they are explicitly saved
- if a saved query is deleted, any linked thread reference remains as thread-only chat history; if the source chat thread is deleted, saved queries simply lose their `chat_source`

Meta-level docs rule:
- whenever new API areas are added, review the top-level OpenAPI `info.description`, tag descriptions, and this reference so the docs still describe the app's current API surface accurately
- avoid describing the whole API as if it were only the first feature area we documented

## Why these docs exist
- Humans need a browsable contract reference for product and integration work.
- Chat/runtime work needs a stable, typed contract that explains payloads, response shapes, role/scope rules, and error semantics.
- A good OpenAPI document reduces prompt bloat because more behavior can be expressed in the contract itself.
- For workspace chat specifically, the API/tool contract should remain the authoritative description of required fields and validation behavior, while recent conversational state is supplied separately by the chat runtime.

## Scalar setup
- Library: Scalar API Reference (open source docs UI rendered from OpenAPI).
- Entry points:
  - controller: `app/controllers/dev/api_docs_controller.rb`
  - view: `app/views/dev/api_docs/show.html.erb`
  - spec source: `config/openapi/v1.json`
- Current embed approach:
  - script-tag embed with `id="api-reference"` and `data-url="/dev/api/openapi.json"`
  - Scalar bootstraps from the CDN script loaded in the ERB view
  - custom CSS is injected in the same view for layout polish
- Current UI choices:
  - `searchHotKey: "k"`
  - sidebar width and spacing tuned for readability

## OpenAPI authoring rules
Every documented operation must include:
1. stable `operationId`
2. short, scannable `summary`
3. fuller `description` that explains intent, scope, and important behavioral constraints
4. typed request schema
5. typed success response schema
6. concrete request and response examples
7. explicit error responses that match real controller behavior
8. accurate auth model and path parameters

For docs to stay human and LLM friendly:
- Use short nav labels in `summary` so the Scalar sidebar does not wrap awkwardly.
- Put nuanced behavior in `description`, not in long summaries.
- Prefer operation-specific response schemas over one generic `data: object` shell.
- Include examples that reflect real app behavior, not hypothetical payloads.
- Document role/scope semantics where they materially affect execution.
- Keep wording contract-like and unambiguous.
- Do not hardcode staging or production hostnames in the spec.
- Use relative server URLs or Scalar environment variables instead of environment-specific domains.

## Scalar/OpenAPI extensions in use
- `x-tagGroups`
  - groups operations into higher-level nav sections
- `x-displayName`
  - keeps tag naming clean in the UI
- `x-codeSamples`
  - adds ready-to-scan request examples
- `x-scalar-environments`
  - provides docs/client variable defaults without hardcoding deploy hosts
- `x-scalar-active-environment`
  - sets the default Scalar environment

## Consumption model
- Product UI consumes the API through Rails controllers/services directly.
- Chat does not call `/api/v1` over HTTP today; it uses the same underlying server-side execution contracts through the shared tool registries and action executor.
- The API docs still matter for chat because they define the public-facing contract language we want tools and future consumers to follow.
- Datasource and query contracts should stay semantically aligned across:
  - standalone UI flows
  - `/api/v1`
  - chat tool execution
- Query provenance should also stay aligned across those surfaces:
  - thread-local chat query references remain private to the thread owner
  - saved query API responses may expose `chat_source` only when that viewer can still access the source thread

## Maintenance workflow
When changing any documented workspace/team/datasource/query API behavior:
1. update controller/service behavior first
2. update `config/openapi/v1.json` in the same change
3. update any relevant master refs if semantics changed
4. run `bundle exec rake openapi:validate`
5. run `bundle exec rspec spec/requests/dev/api_docs_spec.rb`
6. run the relevant API request specs
7. open `/dev/api` and check:
   - sidebar labels do not wrap badly
   - request examples are accurate
   - response examples match real payloads
   - auth/error semantics are understandable at a glance

## Drift guardrails
- Treat the OpenAPI file as a maintained product contract, not generated marketing copy.
- If an endpoint changes and the spec is not updated in the same PR/change, that is a bug.
- If docs become accurate for humans but too vague for tool use, that is still drift.
- If docs become richly structured but unreadable in the UI, that is also drift.

## Environment guidance
- No separate env vars are required just to serve `/dev/api`.
- Keep docs environment-safe:
  - no hardcoded staging/prod hosts in examples
  - prefer current-origin/relative paths
  - use Scalar environment variables when docs need parameterized examples

## Verification baseline
- `bundle exec rake openapi:validate`
- `bundle exec rspec spec/requests/dev/api_docs_spec.rb`
- relevant API request specs under `spec/requests/api/v1`
- manual browser check at `/dev/api`
