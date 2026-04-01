# Queries Master Reference

Last updated: 2026-04-01

## Purpose
Single source of truth for query editor behavior, query-library rules, saved-query identity, and chat/query interaction contracts.

Related references:
- `docs/API_MASTER_REF.md`
- `docs/CHAT_MASTER_REF.md`
- `docs/DATA_SOURCES_MASTER_REF.md`
- `docs/VISUALIZATIONS_THEMING_MASTER_REF.md`
- `docs/WORKSPACES_MASTER_REF.md`
- `docs/ROLES_RIGHTS_MASTER_REF.md`

## Query surfaces
- Query library index:
  - `GET /app/workspaces/:workspace_id/queries`
- Query editor draft entry:
  - `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries`
- Saved query page:
  - `GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:id`
- Saved query API:
  - `GET /api/v1/workspaces/:workspace_id/queries`
  - `POST /api/v1/workspaces/:workspace_id/queries`
  - `PATCH /api/v1/workspaces/:workspace_id/queries/:id`
  - `DELETE /api/v1/workspaces/:workspace_id/queries/:id`
  - `POST /api/v1/workspaces/:workspace_id/queries/run`
- Query visualization app/editor routes:
  - `PUT /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:query_id/visualization`
  - `DELETE /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:query_id/visualization`
- Query visualization API:
  - `GET /api/v1/workspaces/:workspace_id/queries/:query_id/visualization`
  - `PATCH /api/v1/workspaces/:workspace_id/queries/:query_id/visualization`
  - `DELETE /api/v1/workspaces/:workspace_id/queries/:query_id/visualization`

## Query-owned visualization model
- Saved query visualizations are query-owned.
- In phase 1, each query can have zero or one saved visualization.
- Visualization persistence lives in `QueryVisualization`, not on the `queries` row itself.
- Query summary payloads may still expose `chart_type` for compatibility/readability, but the canonical visualization state now lives in the visualization association.
- Structured visualization state is intentionally domain-shaped for future API/chat generation:
  - `chart_type`
  - `theme_reference`
  - `data_config`
  - `appearance_config_dark`
  - `appearance_config_light`
  - `other_config`

## Visualization behavior
- The query editor visualization tab now follows this section order:
  - `Preview`
  - `Data`
  - `Appearance`
  - `Sharing`
  - `Other`
- Sharing is placeholder-only in this phase:
  - no public URLs
  - no embed code
  - no visibility toggles
- Query preview follows the current device/system dark-light mode.
- Current parity chart scope:
  - `table`
  - `total`
  - `line`
  - `area`
  - `column`
  - `bar`
  - `pie`
  - `donut`
- Chart rendering now uses ECharts for chart types and sqlbook-owned rendering for `table` / `total`.

## Themes
- Query visualizations select a workspace-visible theme by `theme_reference`.
- A workspace may define reusable visualization themes in workspace settings under `Branding`.
- The built-in `Default Theming` theme is visible in every workspace, is read-only, and becomes the effective default whenever the workspace has not chosen a workspace-owned default theme.
- Per-chart appearance overrides are stored separately for dark and light mode and merge over the selected theme at render time.

## Draft vs saved behavior
- Unsaved query drafts should not create a `queries` row just because the editor or chat displays them.
- Opening a draft from chat into the query editor should prefill the editor using request params or equivalent transient state.
- If the user closes the tab or navigates away without saving, the draft should disappear.
- A query becomes a saved-library object only when the user explicitly saves it.
- Saving a draft from the query editor settings tab should use the same duplicate rules as chat:
  - exact duplicate saved SQL should resolve to the existing saved query rather than surfacing a generic save failure
  - naming a draft for the first time should promote that draft to `saved: true`

## Saved query identity
- Exact saved-query identity is app-owned, not LLM-owned.
- Exact duplicate means:
  - same datasource
  - same normalized SQL fingerprint
- Exact duplicates should not create another saved query row.
- `POST /queries` should return the existing saved query with `save_outcome: "already_saved"` for an exact duplicate.
- Auto-generated names may collide with a different saved query:
  - if the SQL is not an exact duplicate, chat should ask whether to keep the generated name or choose another
  - explicit user-provided names are still respected

## In-place updates
- Saved queries can be updated in place with:
  - SQL only
  - name only
  - SQL and name together
- `query.rename` is the name-only path.
- `query.update` is the SQL-or-SQL+name path.
- After a SQL-changing `query.update`, the server should run a query-title review for the saved query:
  - `aligned` means the current title still fits and no rename hint should be emitted
  - `stale` means the current title is misleading and the response may include `suggested_name`, `next_actions`, and a persisted `query_rename_suggestion`
  - `uncertain` means the system should not assume the rename and should ask explicitly if the user wants to rename it
- Rename hints should not be emitted for every SQL edit. They are only appropriate when the current saved-query name now reads as meaningfully stale or misleading relative to the updated query.
- If an update would collide with another saved query fingerprint in the same datasource, it must fail validation rather than overwrite or duplicate the other query.

## Chat query cards
- Successful `query.run` turns should render as a structured query card.
- Successful `query.update` turns that include SQL updates should also render as a structured query card, using the updated SQL/result payload rather than stale prior draft state.
- Current card sections:
  - `Query` drawer
  - `Results` drawer
- Initial state:
  - `Query` closed
  - `Results` open
- The query drawer body should include a datasource row that:
  - shows the datasource name
  - links to datasource settings in a new tab
  - can reveal schema/table metadata inline, using the same selector-and-schema-table behavior as the main query editor
- Unsaved query cards show:
  - `Save Query`
  - `Open in query editor`
- Saved query cards remove `Save Query`.
- Refinement cards based on a saved query show:
  - `Save Changes`
  - `Save as new`
  - `Open in query library`
- Query cards produced from an in-place `query.update` of a saved query should render in saved-query mode for that updated query identity (not as an unsaved draft card).
- Query adjustments should render as a new query card lower in the chat stream, not mutate prior result cards.
- Query cards and action suggestions should be driven from structured execution data:
  - `presentation` for the app-rendered card payload
  - `next_actions` for optional follow-up actions the assistant is allowed to suggest
  - `follow_up` for persisted unresolved-next-step state such as query rename suggestion

## Chat/editor/query-library interaction
- `Open in query editor` from a chat query card should open in a new tab.
- That editor view should be prefilled as an unsaved draft unless the query is already saved.
- Saving in chat and saving in the query editor should converge on the same saved query identity rules:
  - exact duplicate => no new row
  - obvious refinement of a saved query => update in place
  - material drift => ask whether to update+rename or save as new
- Refinement continuity is intentionally narrower than full saved-query drift review:
  - keep refinement linkage for same-source, same-order edits such as adding/removing columns or changing the `LIMIT`
  - break refinement linkage for source/order flips that materially change the meaning of the query, for example `oldest users` -> `newest users`, even if the table stays the same
  - when refinement linkage breaks, the next result should render as a fresh unsaved query card rather than a saved-query edit card
- If an unsaved chat query is opened in the query editor and then saved there, the originating chat query card should reconcile into saved mode as well:
  - remove `Save Query`
  - link to the saved query/library object instead of continuing to present as an unsaved draft
  - exact-duplicate saves that resolve to an existing saved query should reconcile the card the same way
- Query-refinement targeting should be explicit:
  - use linked reference fields (`saved_query_id` / `refined_saved_query_id`) when deciding update-vs-new behavior
  - do not infer a saved-query refinement target from stale fallback state alone
- Natural-language query follow-ups should stay attached to the active query even when the user does not restate `query` or `SQL` explicitly:
  - examples: `include the creation date as well`, `remove created_at`, `let's just focus on workspace name and creation date`
  - do not drop to generic capability help just because the follow-up is phrased conversationally
  - do not treat `workspace` as automatically non-query language when the active focus is a datasource query about workspace records
- Saved query links rendered in chat should open the saved query page in a new tab.
- If a saved query is deleted later, old chat links may still exist in the transcript:
  - following one should redirect to query library home
  - show an error toast that the query no longer exists

## Provenance
- Saved queries may optionally link back to their chat origin via `chat_source`.
- `chat_source` is shown only when the current viewer can still access the source thread.
- Deleting a saved query removes the library object but should not erase thread-local chat history.
- Deleting the source chat thread removes the provenance link from the saved query.

## Permissions
- `query.list` is allowed for all accepted workspace roles.
- `query.run`, `query.save`, `query.update`, `query.rename`, and `query.delete` are allowed for `OWNER`, `ADMIN`, and `USER`.
- Query visualization create/update/delete are allowed for `OWNER`, `ADMIN`, and `USER`.
- `READ_ONLY` cannot execute or mutate queries.

## Naming
- Auto-generated saved-query names in chat should be model-generated from the real query purpose, using the SQL plus recent conversational context.
- The saved-query name should help the user find or reference that query later in the app; it should not just mirror visible result columns when the query has a clearer purpose.
- Meaningful filters, ranking, ordering, grouping, or status semantics should be reflected when they define the query, for example `5 longest standing users` instead of `User names and email addresses`.
- If model-based name generation is unavailable, the app should ask the user to provide a name rather than inventing a heuristic fallback title.
- Do not expand heuristic SQL title/name generators into the primary chat save-naming path; lightweight generic helpers are acceptable only for secondary internal surfaces.
- When an auto-generated saved-query name collides with a different existing saved query, chat may pause to reconcile the name. If the user delegates the choice back with `choose another` or `you choose`, the system should generate a concrete alternative and save with that name rather than asking another vague naming question.
- Saved-query title review after `query.update` is also model-first, but the app remains authoritative for:
  - which saved query is under review
  - whether the review result is `aligned`, `stale`, or `uncertain`
  - whether a rename follow-up should be persisted for the current thread
- Query-title review should include the latest natural-language refinement request so the model can sanity-check whether a quantity, ranking direction, timeframe, or status named in the title has become stale after the edit.
