# Emails Master Reference

Last updated: 2026-02-25

## Service and goal
- Service: transactional email delivery in sqlbook.
- Why we use it: deliver authentication codes/links, invitations, account-change verification, and workspace/account lifecycle notifications.
- Outcome we need: predictable, environment-safe email behavior with clear trigger ownership in code.

## Purpose
Single source of truth for what emails exist, when they send, who receives them, and where they are implemented.

Related references:
- `docs/AWS_SES_MASTER_REF.md` for SES account/infrastructure setup.
- `docs/AUTH_MASTER_REF.md` for auth and invitation user flows.
- `docs/ACCOUNT_SETTINGS_MASTER_REF.md` for account settings and email-change/account-deletion flows.
- `docs/WORKSPACES_MASTER_REF.md` for workspace membership and lifecycle flows.

## Delivery architecture
- Base mailer: `app/mailers/application_mailer.rb`
  - default sender: `The Sqlbook Team <noreply@sqlbook.com>`
  - layout: `app/views/layouts/mailer.html.erb`
- Provider by environment:
  - production: `:ses_v2` via `config/environments/production.rb`
  - test: `:test` via `config/environments/test.rb`
- Host/protocol safety:
  - email URL helpers and asset URLs use env-driven Action Mailer config (`APP_PROTOCOL`, `APP_HOST`) in production.
  - no staging/production hostnames should be hardcoded in mailer templates.

## Email inventory

| Email | Mailer + template | Trigger location | Recipient | Subject key |
|---|---|---|---|---|
| Login OTP | `OneTimePasswordMailer.login`<br>`app/views/one_time_password_mailer/login.html.erb` | `app/services/one_time_password_service.rb#create!/resend!` when `auth_type == :login` | login email address | `mailers.one_time_password.subjects.login` |
| Signup OTP | `OneTimePasswordMailer.signup`<br>`app/views/one_time_password_mailer/signup.html.erb` | `app/services/one_time_password_service.rb#create!/resend!` when `auth_type == :signup` | signup email address | `mailers.one_time_password.subjects.signup` |
| Workspace invite | `WorkspaceMailer.invite`<br>`app/views/workspace_mailer/invite.html.erb` | `app/services/workspace_invitation_service.rb#invite!` and `#resend!` | invitee | `mailers.workspace.subjects.invite` |
| Invitation rejected | `WorkspaceMailer.invite_reject`<br>`app/views/workspace_mailer/invite_reject.html.erb` | `app/services/workspace_invitation_service.rb#reject!` | inviter (`member.invited_by`) | `mailers.workspace.subjects.invite_reject` |
| Workspace deleted | `WorkspaceMailer.workspace_deleted`<br>`app/views/workspace_mailer/workspace_deleted.html.erb` | `app/controllers/app/workspaces_controller.rb#destroy` and `app/services/account_deletion_service.rb` | remaining workspace members (excluding actor) | `mailers.workspace.subjects.workspace_deleted` |
| Workspace member removed | `WorkspaceMailer.workspace_member_removed`<br>`app/views/workspace_mailer/workspace_member_removed.html.erb` | `app/controllers/app/workspaces/members_controller.rb#destroy` for accepted members | removed member | `mailers.workspace.subjects.workspace_member_removed` |
| Workspace ownership transferred | `WorkspaceMailer.workspace_owner_transferred`<br>`app/views/workspace_mailer/workspace_owner_transferred.html.erb` | `app/services/account_deletion_service.rb` when transfer action is selected | new owner | `mailers.workspace.subjects.workspace_owner_transferred` |
| Data source deleted | `DataSourceMailer.destroy`<br>`app/views/data_source_mailer/destroy.html.erb` | `app/controllers/app/workspaces/data_sources_controller.rb#destroy` | affected workspace members | `mailers.data_source.subjects.destroy` |
| Email-change verification | `AccountMailer.verify_email_change`<br>`app/views/account_mailer/verify_email_change.html.erb` | `app/controllers/app/account_settings_controller.rb#update` | current account email (old email) | `mailers.account.subjects.verify_email_change` |
| Account deletion confirmed | `AccountMailer.account_deletion_confirmed`<br>`app/views/account_mailer/account_deletion_confirmed.html.erb` | `app/services/account_deletion_service.rb` | deleted user email (captured before destroy) | `mailers.account.subjects.account_deletion_confirmed` |

Subject strings are defined in `config/locales/en.yml` under `en.mailers.*.subjects`.

## Workflow-specific notes
- Invitation creation is transactional with mail send in `WorkspaceInvitationService#invite!`; failed invite delivery rolls back member creation.
- Account deletion actions (workspace delete/transfer + user delete) run in one DB transaction in `AccountDeletionService`.
- Account-deletion confirmation and ownership-transfer emails are sent after transaction completion.
- Notification sends in account/workspace deletion flows are best-effort: send failures are logged and do not roll back deletes.
- `WorkspaceMailer.workspace_member_removed` sets `@unsubscribable = true`, enabling the footer unsubscribe link in `mailer` layout.

## Test coverage and previews
- Mailer specs:
  - `spec/mailers/one_time_password_spec.rb`
  - `spec/mailers/workspace_spec.rb`
  - `spec/mailers/account_spec.rb`
  - `spec/mailers/data_source_spec.rb`
- Flow/service specs:
  - `spec/services/one_time_password_service_spec.rb`
  - `spec/services/workspace_invitation_service_spec.rb`
  - `spec/services/account_deletion_service_spec.rb`
- Mailer previews:
  - `spec/mailers/previews/one_time_password_preview.rb`
  - `spec/mailers/previews/workspace_preview.rb`
  - `spec/mailers/previews/data_source_preview.rb`

## Change checklist for any new/edited email
1. Add/update mailer action in `app/mailers`.
2. Add/update HTML template in `app/views/..._mailer`.
3. Add/update subject key in `config/locales/en.yml`.
4. Ensure links use route URL helpers (no hardcoded hostnames).
5. Add/update mailer and flow specs.
6. Update this file and the relevant domain master reference(s).
