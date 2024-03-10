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
end
