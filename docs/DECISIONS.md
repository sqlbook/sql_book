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
