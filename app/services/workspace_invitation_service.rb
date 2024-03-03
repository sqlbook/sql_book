# frozen_string_literal: true

class WorkspaceInvitationService
  def initialize(workspace:)
    @workspace = workspace
  end

  def accept!(member:)
    member.update!(status: Member::Status::ACCEPTED, invitation: nil)
  end

  def invite!(first_name:, last_name:, email:, role:)
    user = find_or_create_user!(first_name:, last_name:, email:)
    member = create_member!(user:, role:)

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

  def create_member!(user:, role:)
    Member.create!(
      user:,
      workspace:,
      role:,
      status: Member::Status::PENDING,
      invitation: SecureRandom.base36
    )
  end
end
