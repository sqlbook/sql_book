# frozen_string_literal: true

class WorkspaceDeletionService
  Result = Struct.new(:success?, :failed_notifications, keyword_init: true)

  def initialize(workspace:, deleted_by:)
    @workspace = workspace
    @deleted_by = deleted_by
  end

  def call
    users_to_notify = workspace_users_to_notify
    workspace_name = workspace.name
    deleted_by_name = deleted_by.full_name

    workspace.destroy!
    failed_notifications = notify_workspace_deleted_users!(
      users: users_to_notify,
      workspace_name:,
      workspace_owner_name: deleted_by_name
    )

    Result.new(success?: true, failed_notifications:)
  rescue StandardError => e
    Rails.logger.error("Workspace deletion failed for workspace #{workspace.id}: #{e.class} #{e.message}")
    Result.new(success?: false, failed_notifications: 0)
  end

  private

  attr_reader :workspace, :deleted_by

  def workspace_users_to_notify
    workspace.members.includes(:user).map(&:user).uniq.reject { |user| user.id == deleted_by.id }
  end

  def notify_workspace_deleted_users!(users:, workspace_name:, workspace_owner_name:)
    users.count do |user|
      WorkspaceMailer.workspace_deleted(
        user:,
        workspace_name:,
        workspace_owner_name:
      ).deliver_now
      false
    rescue StandardError => e
      Rails.logger.error("Workspace delete notification failed for user #{user.id}: #{e.class} #{e.message}")
      true
    end
  end
end
