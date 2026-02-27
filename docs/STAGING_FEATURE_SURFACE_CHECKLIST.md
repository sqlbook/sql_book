# Staging Feature Surface Checklist

Last updated: 2026-02-26

## Purpose
Maintain a lightweight staging smoke gate for high-risk behavior while sqlbook is pre-production only.

## How to use
- Use this checklist for quick regression checks after larger changes.
- Keep it focused on highest-risk paths only.
- Do not expand this with low-risk visual polish checks.

## Relation to Master References
- The canonical behavior lives in the master refs (`AUTH`, `WORKSPACES`, `ACCOUNT_SETTINGS`, `ROLES_RIGHTS`, `TOASTS`, `EMAILS`).
- Full UAT planning should be generated from those master refs near production readiness.
- This file is intentionally a short operational subset, not the full product spec.

## Critical staging checks

### Auth and sessions
- [ ] Signup/login OTP flow still works end-to-end.
- [ ] Invitation accept/reject flow works with expected redirects and terms acceptance.
- [ ] Signout returns user to logged-out state correctly.

### Authorization and role safety
- [ ] Workspace access denies non-members with `Workspace not available` redirect/toast.
- [ ] Owner/admin-only pages/actions are blocked for user/read-only roles.
- [ ] Team role update and invite permissions still enforce role hierarchy.

### Destructive and irreversible flows
- [ ] Workspace delete flow succeeds for owner and blocks non-owner.
- [ ] Account delete flow enforces per-workspace outcomes and completes delete/transfer behavior.
- [ ] Post-delete toasts and redirects are correct for actor.

### Email-linked critical flows
- [ ] Account email-change verification link succeeds within validity window.
- [ ] Expired/invalid verification links fail safely with correct redirect/toast.
- [ ] Account deletion confirmation + ownership transfer emails send in expected scenarios.

### Realtime and invitation visibility
- [ ] Pending invitation toast appears for signed-in invited user without manual refresh.
- [ ] Team membership updates appear without full page reload in workspace settings.
