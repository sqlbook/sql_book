# frozen_string_literal: true

class WorkspaceMailer < ApplicationMailer
  def invite(member:)
    @member = member
    with_recipient_locale(recipient: member.user) do
      mail(to: member.user.email, subject: I18n.t('mailers.workspace.subjects.invite'))
    end
  end

  def invite_reject(member:)
    @member = member
    with_recipient_locale(recipient: member.invited_by) do
      mail(to: member.invited_by.email, subject: I18n.t('mailers.workspace.subjects.invite_reject'))
    end
  end

  def workspace_deleted(user:, workspace_name:, workspace_owner_name:)
    @workspace_name = workspace_name
    @workspace_owner_name = workspace_owner_name

    with_recipient_locale(recipient: user) do
      mail(to: user.email, subject: I18n.t('mailers.workspace.subjects.workspace_deleted'))
    end
  end

  def workspace_member_removed(user:, workspace_name:)
    @workspace_name = workspace_name
    @unsubscribable = true

    with_recipient_locale(recipient: user) do
      mail(to: user.email, subject: I18n.t('mailers.workspace.subjects.workspace_member_removed'))
    end
  end

  def workspace_owner_transferred(new_owner:, workspace:, previous_owner_name:)
    @workspace = workspace
    @workspace_name = workspace.name
    @previous_owner_name = previous_owner_name

    with_recipient_locale(recipient: new_owner) do
      mail(
        to: new_owner.email,
        subject: I18n.t('mailers.workspace.subjects.workspace_owner_transferred', workspace_name: workspace.name)
      )
    end
  end
end
