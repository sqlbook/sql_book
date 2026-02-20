# frozen_string_literal: true

class WorkspaceMailer < ApplicationMailer
  def invite(member:)
    @member = member
    mail(to: member.user.email, subject: I18n.t('mailers.workspace.subjects.invite'))
  end

  def invite_reject(member:)
    @member = member
    mail(to: member.invited_by.email, subject: I18n.t('mailers.workspace.subjects.invite_reject'))
  end

  def workspace_deleted(user:, workspace_name:, workspace_owner_name:)
    @workspace_name = workspace_name
    @workspace_owner_name = workspace_owner_name

    mail(to: user.email, subject: I18n.t('mailers.workspace.subjects.workspace_deleted'))
  end

  def workspace_member_removed(user:, workspace_name:)
    @workspace_name = workspace_name
    @unsubscribable = true

    mail(to: user.email, subject: I18n.t('mailers.workspace.subjects.workspace_member_removed'))
  end
end
