# frozen_string_literal: true

class WorkspaceInvitationService
  def initialize(workspace:)
    @workspace = workspace
  end

  def accept!(member:)
    member.update!(status: Member::Status::ACCEPTED, invitation: nil)
  end

  def reject!(member:)
    user = member.user
    member.destroy

    WorkspaceMailer.invite_reject(member:).deliver_now

    user.destroy if user.workspaces.empty?
  end

  def invite!(invited_by:, first_name:, last_name:, email:, role:)
    user = find_or_create_user!(first_name:, last_name:, email:)
    member = create_member!(user:, role:, invited_by:)

    WorkspaceMailer.invite(member:).deliver_now
  end

  private

  attr_reader :workspace

  def find_or_create_user!(first_name:, last_name:, email:)
    User.find_or_create_by!(email:) do |user|
      user.first_name = first_name
      user.last_name = last_name
      user.email = email
    end
  end

  def create_member!(user:, role:, invited_by:)
    Member.create!(
      user:,
      workspace:,
      role:,
      status: Member::Status::PENDING,
      invitation: SecureRandom.base36,
      invited_by:
    )
  end
end
