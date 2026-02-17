# GitHub Project Draft

Last updated: 2026-02-16

## Purpose
Draft configuration for GitHub Issues + Project board, aligned with `docs/GITHUB_WORKING_AGREEMENT.md`.

## Project columns
- `Backlog`
- `Todo`
- `In Progress`
- `Blocked`
- `Done`

## Status rules
- New issues default to `Backlog`.
- Codex can create issues in `Backlog` and comment for clarification.
- Codex must not move an issue out of `Backlog` without explicit user approval.
- `Done` requires all completion gates from the working agreement.

## Clarification channel rule
- If user and Codex are actively online in a synchronous session, clarifying questions should be asked in chat first.
- If not in a synchronous session, use issue comments for clarifying questions and status updates.

## Access operations rule
- Codex GitHub operations run with temporary API access provided by the user.
- The user may routinely generate and revoke tokens as part of normal workflow.
- When token access is revoked, board/issue operations pause until new temporary access is provided.

## Label taxonomy

### Type labels
- `type:bug`
- `type:feature`
- `type:tech-debt`
- `type:docs`
- `type:chore`

### Priority labels
- `priority:p0`
- `priority:p1`
- `priority:p2`
- `priority:p3`

### Area labels
- `area:marketing-website`
- `area:authentication`
- `area:app-workspaces`
- `area:app-data-sources`
- `area:app-queries`
- `area:app-dashboards`

### State/risk labels
- `state:needs-clarification`
- `state:blocked-external`
- `state:needs-docs-update`
- `risk:high`

## Suggested issue template fields
- `Summary`
- `Problem`
- `Proposed change`
- `Acceptance criteria`
- `Area` (single area label)
- `Priority` (single priority label)
- `Out of scope`
- `Docs impact` (which `*.md` files require updates)

## Done checklist for each issue
- [ ] Behavior implemented
- [ ] Self-review completed
- [ ] Tests/lint run (or gap documented)
- [ ] Relevant `*.md` docs updated (or explicitly not needed)
- [ ] Final issue comment summarizes result and follow-ups
