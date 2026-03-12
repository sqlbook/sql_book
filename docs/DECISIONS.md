# Architecture Decisions Log

Use this file to record major choices and why they were made.

## 2026-02-14
### Decision: Keep Postgres for relaunch
- Status: Accepted
- Why:
  - already integrated and working
  - fastest path to relaunch
  - lowest migration risk while product scope is still evolving
- Revisit when:
  - analytical query performance or cost becomes unacceptable after normal optimization

### Decision: Use phased approach (Relaunch -> Expansion -> Scale)
- Status: Accepted
- Why:
  - avoids premature complexity
  - fits team capacity and LLM-assisted workflow

## 2026-02-19
### Decision: Use push-based UI refresh for workspace membership/invitation state
- Status: Accepted
- Why:
  - reduces stale UI states in team management and invitation UX
  - avoids broad polling loops and unnecessary network churn
  - aligns well with existing Rails/Turbo stack
- Consequences:
  - requires ActionCable route availability (`/cable`) in deployed environments
  - member create/update/destroy now drives Turbo Stream refresh behavior
- Revisit when:
  - workload or connection count makes stream fan-out a bottleneck

### Decision: Prefer EU region hosting
- Status: Accepted
- Why:
  - privacy/data residency requirements and customer trust

## 2026-03-07
### Decision: Use connector-type strategy (live-query first for external SQL in v1)
- Status: Accepted
- Why:
  - supports the product shift from first-party-only capture to multi-source workspaces
  - delivers the first external connector faster by avoiding full ingest pipeline work
  - keeps operational complexity lower during relaunch
  - fits current architecture where first-party capture already has strong tenant isolation controls
- Consequences:
  - supersedes the earlier ingest-first connector assumption in `/Users/chrispattison/sql_book/docs/ARCHITECTURE_PLAN.md`
  - external SQL connectors use read-only live querying in v1; full ingestion is not the default
  - API/SaaS connectors may still require selective sync/materialization where live querying is impractical
  - temporary query-result caching must remain tenant-scoped and treated as controlled temporary storage
  - first-party captured events remain centralized with strict per-tenant access controls (RLS model preserved)
- Revisit when:
  - external API/rate-limit constraints make live querying unreliable for core use cases
  - performance/cost of live querying becomes unacceptable for target workloads
  - cross-source federation requirements demand a different storage/execution model

### Decision: Ship workspace-scoped chat with strict action allowlist in v1
- Status: Accepted
- Why:
  - enables useful in-product assistant behavior without expanding system risk surface
  - keeps parity with existing server-side workspace/team behavior and side effects
  - allows incremental delivery toward broader chat-driven workflows
- Consequences:
  - chat actions are constrained to workspace/team management in v1
  - high-risk mutating actions require inline confirmation; low-risk writes auto-run
  - payloads carry workspace/thread/message identifiers and are scope-validated server-side
  - fixed/system chat copy is locale-key based (`en`/`es`) rather than hardcoded
- Revisit when:
  - data source/query/dashboard chat actions are implemented with equivalent policy/confirmation guarantees
  - thread switching/history UX becomes a surfaced user feature

## 2026-03-09
### Decision: Move chat orchestration to LLM-first runtime with shared tool registry
- Status: Accepted
- Why:
  - improves conversational quality by using one structured model decision path instead of heavy heuristic routing
  - creates reusable cross-product tooling infrastructure beyond chat
  - centralizes schema validation and normalized execution/error handling
- Consequences:
  - chat runtime now uses structured `assistant_message/tool_calls/missing_information/finalize_without_tools` output
  - `Tooling::Registry` + workspace/team tool catalog are now the canonical execution surface
  - write idempotency keys prevent duplicate side effects on retries
  - API v1 workspace/team routes and public Scalar docs (`/dev/api`) are now maintained contracts
  - `docs/API_MASTER_REF.md` owns the API-doc setup and maintenance workflow
  - Responses API strict `json_schema` does not tolerate our open-ended dynamic nested argument objects, so runtime/planner now serialize dynamic tool arguments/payloads as JSON strings and parse them server-side
- Revisit when:
  - broader domain namespaces (`datasource.*`, `query.*`, `dashboard.*`) are promoted into shared tooling
  - model/provider strategy changes require runtime contract updates

### Decision: Require explicit first + last name for workspace invites (and signup identity)
- Status: Accepted
- Why:
  - invitation and onboarding emails rely on real user identity fields
  - avoids weak/ambiguous invite payloads derived from partial or placeholder text
  - improves deterministic validation and translation-safe follow-up prompts
- Consequences:
  - `member.invite` now requires `first_name`, `last_name`, `email` in tool schema and API contract
  - chat runtime/planner follow-ups collect missing invite fields instead of executing with partial data
  - signup identity gate for OTP step requires non-blank `email`, `first_name`, `last_name`
- Revisit when:
  - ownership transfer + advanced identity workflows are added to chat and API surfaces

## Template
### Decision: <title>
- Status: Proposed | Accepted | Rejected | Superseded
- Date: YYYY-MM-DD
- Why:
  - <reason>
- Consequences:
  - <tradeoff>
- Revisit when:
  - <trigger>
