# frozen_string_literal: true

class WorkspaceMailer < ApplicationMailer
  def invite(member:)
    @member = member
    mail(to: member.user.email, subject: I18n.t('mailers.workspace.subjects.invite'))
  end
end
