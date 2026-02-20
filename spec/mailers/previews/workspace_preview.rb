# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/workspace
class WorkspacePreview < ActionMailer::Preview
  def invite
    member = Member.first
    member.invited_by_id = member.user.id
    member.invitation = 'token' # This is only in memory but works fine for a preview
    WorkspaceMailer.invite(member:)
  end

  def invite_reject
    member = Member.first
    member.invited_by_id = member.user.id
    WorkspaceMailer.invite_reject(member:)
  end

  def workspace_member_removed
    member = Member.first
    WorkspaceMailer.workspace_member_removed(user: member.user, workspace_name: member.workspace.name)
  end
end
