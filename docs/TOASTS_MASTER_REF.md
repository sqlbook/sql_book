# Toasts Master Reference

Last updated: 2026-02-21

## Purpose
Define copy and rendering rules for in-app toasts so messaging stays consistent and safe.

## Source of truth
- Locale keys: `/Users/chrispattison/sql_book/config/locales/en.yml`
- Toast renderer: `/Users/chrispattison/sql_book/app/views/shared/_toasts.html.erb`
- Current workspace-settings save toasts:
  - `toasts.workspaces.updated`
  - `toasts.workspaces.update_failed`

## Copy and encoding rules
- Toast `title` and default `body` values are rendered as plain text.
- Do not use HTML entities in locale strings for toast copy (for example `&apos;`, `&amp;`, `&quot;`).
- Use normal punctuation directly in locale strings (for example `We've`, not `We&apos;ve`).
- Keep toast copy single-paragraph and concise unless the product explicitly needs multi-step copy.

## Interpolation rules
- Use `%{variable}` placeholders for dynamic values.
- Pass interpolation values from controller/service when constructing toasts.
- Treat interpolated values as untrusted user data and keep renderer escaping enabled.
- If variable emphasis is required (for example email addresses), provide both:
  - plain `body` string for fallback/logging
  - sanitized `body_html` with `<strong>` wrappers around interpolated variables
- Only allow minimal inline markup in toast HTML (`<strong>` currently) and sanitize at render time.
- Emphasized variables should use darker-color emphasis in toast body copy, without heavier font weight.

## Link/action rules
- Toast action links inside the app should use internal paths (`/app/...`) not hardcoded absolute hosts.
- Use absolute URLs only for truly external destinations.
