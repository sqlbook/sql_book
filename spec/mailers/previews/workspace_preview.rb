# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/workspace
class WorkspacePreview < ActionMailer::Preview
  def invite
    member = Member.first
    WorkspaceMailer.invite(member:)
  end
end
