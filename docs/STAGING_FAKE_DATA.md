# Staging Fake Data

Use these tasks to seed richer fake workspace/member data in staging or development without touching real workspaces.

## What it creates
- 10 to 15 fake workspaces by default (`Seed Workspace 01`, `Seed Workspace 02`, ...)
- realistic-looking fake users on the `seed.sqlbook.test` domain
- accepted memberships only; no invitation emails are sent
- `Chris Pattison <chris.pattison@protonmail.com>` added to every fake workspace
- Chris role mix rotates across:
  - `Admin`
  - `User`
  - `Read only`
- team sizes rotate from 2 to 5 total accepted members
- varied `created_at` / `updated_at` / `last_active_at` timestamps

## Seed command

```bash
bundle exec rake staging:fake_data:seed_workspaces
```

Optional overrides:

```bash
COUNT=12 PREFIX="Seed Workspace" CHRIS_EMAIL="chris.pattison@protonmail.com" bundle exec rake staging:fake_data:seed_workspaces
```

## Cleanup command

```bash
bundle exec rake staging:fake_data:cleanup_workspaces
```

This removes:
- workspaces whose names start with the configured prefix
- fake users on the configured fake email domain

## Safety
- These tasks only run in `staging` or `development`.
- Render staging currently runs with `RAILS_ENV=production`, so the task also allows the staging deploy shape when `APP_HOST=staging.sqlbook.com`.
- They do not modify existing real workspaces unless a real workspace was manually named with the same fake prefix.
- Fake users are tagged via the `seed.sqlbook.test` email domain so cleanup can stay targeted.
