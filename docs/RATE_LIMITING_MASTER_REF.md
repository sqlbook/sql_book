# Rate Limiting

Last updated: 2026-03-22

## Current Scope
- sqlbook now uses `Rack::Attack` for a first targeted rate-limiting pass.
- The currently shipped throttles cover:
  - authentication code send and verify flows
  - chat message submission
  - chat action confirm/cancel
  - query execution via the public API
  - data source validation and creation via both API and app routes

## Current Design
- Auth routes are limited by IP and email identifier.
- Authenticated app/API routes are limited primarily by the current session user id, with IP as the fallback.
- API and chat throttles return JSON `429` payloads with:
  - `status`
  - `error_code`
  - `message`
  - `retry_after_seconds`
- HTML form routes return `429` with a plain user-facing message.

## First-Batch Limits
- Auth send-code flows:
  - `5 requests / 15 minutes`
- Auth verify flows:
  - `10 requests / 10 minutes`
- Chat messages:
  - burst: `5 requests / 30 seconds`
  - sustained: `20 requests / 5 minutes`
- Chat action confirm/cancel:
  - `30 requests / 5 minutes`
- Query run:
  - burst: `5 requests / 30 seconds`
  - sustained: `20 requests / 5 minutes`
- Data source validate:
  - `10 requests / 10 minutes`
- Data source create:
  - `10 requests / 30 minutes`

## Deferred Work
- Consider extending throttles to:
  - query save/update/delete
  - team invite/member mutation flows
  - workspace settings mutations
  - dashboard write operations
- Add richer observability around throttle hits:
  - dedicated metrics by throttle family
  - dashboarding and alerting for sustained abuse
- Revisit the thresholds using real production usage after soak testing.
- Consider more product-native HTML handling for throttled auth and data-source form submissions if the plain `429` copy feels too abrupt.

## Notes
- Rate limiting is intentionally targeted rather than global.
- Expensive or abuse-prone routes are prioritized first.
- Future expansion should be driven by usage data rather than broad theoretical coverage.
