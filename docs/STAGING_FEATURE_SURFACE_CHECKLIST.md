# Staging Feature Surface Checklist

Last updated: 2026-02-16

## Purpose
Track additional functionality beyond the core baseline as the product expands.

This checklist is intentionally dynamic. Add items whenever new user-facing behavior ships.

## How to use
- Keep this list aligned with currently released features in the app.
- Validate new items in staging before production planning.
- Do not move items into core unless they become mandatory for go-live.

## Current feature surface

### Query authoring UX
- [ ] Query library/search interactions work as expected.
- [ ] Schema explorer renders and updates with selected data source.
- [ ] Query form validation and submit behavior are correct.

### Saved queries and charts
- [ ] Save query flow works end-to-end.
- [ ] Existing saved query loads and executes correctly.
- [ ] Chart type switching renders expected output.
- [ ] Chart configuration updates persist and re-render correctly.

### Table and result interactions
- [ ] Pagination controls operate correctly across pages.
- [ ] Table row context/actions open and close correctly.
- [ ] Copy/share interactions (where present) work in major browsers.

### Workspace navigation and management
- [ ] Workspace switcher updates URL/state correctly.
- [ ] Data source switcher updates query context correctly.
- [ ] Any workspace settings/membership pages load and save changes.

### Background workflows
- [ ] Async jobs tied to non-core features complete successfully.
- [ ] Retries/dead-letter behavior is visible and actionable.

### Integrations and external services
- [ ] SES email behavior for non-auth mailers works (if used).
- [ ] Sentry/monitoring integration behaves as expected when enabled.

## Change control
- Add new rows in the same PR that introduces the feature.
- Remove rows only when a feature is deleted from the product.
- During release readiness reviews, capture pass/fail/date per item in release notes.
