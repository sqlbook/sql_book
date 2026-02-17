# GitHub Working Agreement

Last updated: 2026-02-16

## Purpose
Define how we use GitHub Issues/Project for planning and execution so ticket state always reflects real status.

## Board workflow
- New issues are created in `Backlog`.
- Codex may only:
  - create issues in `Backlog`
  - add issue comments (status notes, clarifying questions, findings)
- Codex must not move an issue out of `Backlog` or begin implementation until explicit user approval.
- After explicit approval, Codex may move the issue to `In Progress`.
- When blocked, move to `Blocked` with a clear blocker comment.
- Move to `Done` only when all completion gates below are satisfied.

## Communication rules
- If user and Codex are actively online in a synchronous session, clarifying questions should be asked in chat first.
- If not in a synchronous session, use issue comments for clarifying questions.
- Use issue comments for clarifying questions and execution updates.
- Keep decisions and scope changes in the issue thread.
- If screenshots are provided, Codex will review them.
- If videos are provided, include a short written summary and key screenshots for reliable analysis.

## API access model
- GitHub API access for Codex is provided via temporary user-generated tokens.
- The user is comfortable generating and revoking tokens routinely.
- Tokens should be short-lived and treated as disposable session credentials.
- When token access is revoked, Codex cannot operate GitHub issues/projects until a new temporary token is provided.
- Prefer secure handoff methods (for example local temp file) over posting tokens in chat.

## Completion gates (required before `Done`)
- Codex has completed a self-review of the implementation.
- Relevant tests/lint have been run, or any gaps are explicitly documented.
- Any relevant `*.md` documentation is updated.
- If docs updates are not required, this is stated in the issue comment before closure.

## Definition of done
- Requested behavior is implemented and verified.
- No known blocker remains for the issue scope.
- Documentation and issue comments reflect final behavior and decisions.
