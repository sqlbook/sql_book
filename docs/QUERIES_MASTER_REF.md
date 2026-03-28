# Queries Master Reference

Last updated: 2026-03-27

## Purpose
Single source of truth for query editor behavior, query-library rules, saved-query identity, and chat/query interaction contracts.

Related references:
- `docs/API_MASTER_REF.md`
- `docs/CHAT_MASTER_REF.md`
- `docs/DATA_SOURCES_MASTER_REF.md`
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

## Chat/editor/query-library interaction
- `Open in query editor` from a chat query card should open in a new tab.
- That editor view should be prefilled as an unsaved draft unless the query is already saved.
- Saving in chat and saving in the query editor should converge on the same saved query identity rules:
  - exact duplicate => no new row
  - obvious refinement of a saved query => update in place
  - material drift => ask whether to update+rename or save as new
- Query-refinement targeting should be explicit:
  - use linked reference fields (`saved_query_id` / `refined_saved_query_id`) when deciding update-vs-new behavior
  - do not infer a saved-query refinement target from stale fallback state alone
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
- `READ_ONLY` cannot execute or mutate queries.

## Naming
- Auto-generated saved-query names should be concise but specific to the query’s real purpose.
- Meaningful filters should be reflected in the generated name when they materially define the query.
- Generic fallback names like `User count` or `User names and email addresses` are only acceptable when they truly match the query scope.
- When an auto-generated saved-query name collides with a different existing saved query, chat may pause to reconcile the name. If the user delegates the choice back with `choose another` or `you choose`, the system should generate a concrete alternative and save with that name rather than asking another vague naming question.
