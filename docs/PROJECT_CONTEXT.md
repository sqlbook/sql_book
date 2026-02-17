# sqlbook Project Context

## Product Summary
sqlbook lets users:
- install tracking code on their site/app
- store events in sqlbook
- run SQL queries
- save queries and visualizations
- build dashboards (in progress)

## Current Constraints
- Founder-led rebuild with heavy LLM support.
- Prioritize low operational complexity and clear runbooks.
- EU hosting/data residency is preferred for privacy and compliance posture.

## Near-Term Priorities
1. Stable staging environment (`staging.sqlbook.com`).
2. Reliable auth email delivery in staging/production.
3. Core query UX and saved visualizations.
4. Dashboard MVP.
5. Connector architecture design and first connector.

## Architecture Principles
- Optimize for shipping and maintainability over maximal control.
- Prefer managed services when they remove operational burden.
- Keep strong tenant isolation and read-only guarantees for user-executed queries.
- Introduce new infrastructure only when measurable bottlenecks justify it.

