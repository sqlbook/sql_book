# Staging Feature Surface Checklist

Last updated: 2026-02-22

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
- [ ] Team table truncated cells and headers show tooltips on overflow.
- [ ] Copy/share interactions (where present) work in major browsers.

### Workspace navigation and management
- [ ] Workspace switcher updates URL/state correctly.
- [ ] Data source switcher updates query context correctly.
- [ ] Header shows two right-aligned menu icons below `1024px` (`ri-menu-line` and `ri-account-circle-line`) with 16px gap.
- [ ] Header shows desktop layout at `>=1024px`:
  - persistent workspace switcher (160px) 16px right of logo
  - centered workspace nav links (`Chat`, `Data Sources`, `Query Library`, `Dashboards`, `Settings`)
  - account icon on right
- [ ] Workspace menu dropdown aligns right edge to workspace-menu icon and opens 8px below it.
- [ ] Account menu dropdown aligns right edge to account-menu icon and opens 8px below it.
- [ ] Workspace menu width is 180px and includes `Workspace` heading, workspace switcher, `Chat`, `Data Sources`, `Query Library`, `Dashboards`, and `Settings`.
- [ ] Account menu width is 160px and includes `Account` heading, `Settings`, and `Log out`.
- [ ] Any workspace settings/membership pages load and save changes.
- [ ] Workspace settings `[Save Changes]` is disabled until the workspace name field has an unsaved change.
- [ ] Workspace settings name save shows success toast (and error toast on forced/failed save paths).
- [ ] Workspace card settings link/icon is hidden for roles without settings permission.
- [ ] Workspace breadcrumbs render on workspace-scoped pages and do not render on `/app/workspaces`.
- [ ] Breadcrumb `Workspaces` link routes to `/app/workspaces`.
- [ ] On `/app/workspaces/:id`, breadcrumb workspace-name item is non-link current text.
- [ ] On workspace child pages, breadcrumb workspace-name link routes to `/app/workspaces/:id` for all workspace roles.
- [ ] Breadcrumb narrow viewport behavior keeps first/last items and separators visible while middle items truncate.
- [ ] Truncated middle breadcrumb items show tooltip text and remain clickable.
- [ ] Breadcrumb component remains mounted in markup but is temporarily hidden in UI on all pages.
- [ ] Pending invitation toast appears in-app for active sessions with `[View invitation]` action.
- [ ] Team member table updates status/actions without manual refresh when invitation state changes.
- [ ] Team member role select is shown only for editable rows (owner/admin hierarchy rules) and updates role successfully.
- [ ] Team member role change success/failure toasts render with expected copy.
- [ ] Team role dropdowns do not surface `Owner` as an option (ownership transfer flow remains deferred).

### Auth UX polish
- [ ] Signup `[Continue]` button does not shift position when toggling disabled/enabled state.
- [ ] Account settings page (`/app/account-settings`) loads and saves first/last name changes.
- [ ] Account settings email change keeps current email unchanged until verification link is used.
- [ ] Email-change verification link succeeds within 1 hour and redirects to `/app/workspaces` with success toast.
- [ ] Expired email-change verification link redirects to `/app/account-settings` with error toast.

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
