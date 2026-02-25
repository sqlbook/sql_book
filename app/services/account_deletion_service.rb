# frozen_string_literal: true

class AccountDeletionService # rubocop:disable Metrics/ClassLength
  DELETE_WORKSPACE_ACTION = 'delete'

  Result = Struct.new(:success?, :error_key, keyword_init: true)

  class InvalidWorkspaceAction < StandardError; end

  def initialize(user:, workspace_actions:)
    @user = user
    @workspace_actions = normalized_workspace_actions(workspace_actions:)
  end

  def call
    return failure(:account_delete_unresolved_workspaces) unless all_owned_workspaces_resolved?

    deleted_user_email, deleted_user_name, transferred_workspaces = perform_account_deletion!

    deliver_account_deletion_confirmation!(email: deleted_user_email)
    deliver_workspace_transfer_emails!(transferred_workspaces:, deleted_user_name:)

    success
  rescue InvalidWorkspaceAction
    failure(:account_delete_unresolved_workspaces)
  rescue StandardError => e
    Rails.logger.error("Account deletion failed for user #{user.id}: #{e.class} #{e.message}")
    failure(:account_delete_failed)
  end

  private

  attr_reader :user, :workspace_actions

  def perform_account_deletion!
    deleted_user_email = user.email
    deleted_user_name = user.full_name
    transferred_workspaces = []

    ActiveRecord::Base.transaction do
      process_owned_workspaces!(
        deleted_user_name:,
        transferred_workspaces:
      )
      user.destroy!
    end

    [deleted_user_email, deleted_user_name, transferred_workspaces]
  end

  def process_owned_workspaces!(deleted_user_name:, transferred_workspaces:)
    owned_workspaces.each do |workspace|
      process_workspace_action!(
        workspace:,
        deleted_user_name:,
        transferred_workspaces:
      )
    end
  end

  def process_workspace_action!(workspace:, deleted_user_name:, transferred_workspaces:)
    action = resolved_action_for(workspace:)

    if action == DELETE_WORKSPACE_ACTION
      delete_workspace!(workspace:, workspace_owner_name: deleted_user_name)
      return
    end

    promoted_member = promote_new_owner!(workspace:, member_id: action)
    transferred_workspaces << { workspace:, new_owner: promoted_member.user }
  end

  def normalized_workspace_actions(workspace_actions:)
    workspace_actions.to_h.transform_keys(&:to_s).transform_values { |value| value.to_s.strip }
  end

  def owned_workspaces
    @owned_workspaces ||= user.members
      .accepted
      .where(role: Member::Roles::OWNER)
      .includes(workspace: { members: :user })
      .map(&:workspace)
      .uniq
      .sort_by(&:id)
  end

  def eligible_members_for(workspace:)
    workspace.members.select do |member|
      member.status == Member::Status::ACCEPTED &&
        member.user_id != user.id
    end
  end

  def all_owned_workspaces_resolved?
    owned_workspaces.all? do |workspace|
      eligible_members = eligible_members_for(workspace:)
      next true if eligible_members.empty?

      action = workspace_actions[workspace.id.to_s]
      valid_action_for_workspace?(action:, eligible_members:)
    end
  end

  def valid_action_for_workspace?(action:, eligible_members:)
    return false if action.blank?
    return true if action == DELETE_WORKSPACE_ACTION

    eligible_members.any? { |member| member.id.to_s == action }
  end

  def resolved_action_for(workspace:)
    eligible_members = eligible_members_for(workspace:)
    return DELETE_WORKSPACE_ACTION if eligible_members.empty?

    action = workspace_actions[workspace.id.to_s]
    raise InvalidWorkspaceAction unless valid_action_for_workspace?(action:, eligible_members:)

    action
  end

  def promote_new_owner!(workspace:, member_id:)
    member = workspace.members.find_by(id: member_id, status: Member::Status::ACCEPTED)
    raise InvalidWorkspaceAction unless member && member.user_id != user.id

    member.update!(role: Member::Roles::OWNER)
    member
  end

  def delete_workspace!(workspace:, workspace_owner_name:)
    users_to_notify = workspace_users_to_notify(workspace:)
    workspace_name = workspace.name

    workspace.destroy!
    notify_workspace_deleted_users!(
      users_to_notify:,
      workspace_name:,
      workspace_owner_name:
    )
  end

  def workspace_users_to_notify(workspace:)
    workspace.members
      .includes(:user)
      .map(&:user)
      .uniq
      .reject { |workspace_user| workspace_user.id == user.id }
  end

  def notify_workspace_deleted_users!(users_to_notify:, workspace_name:, workspace_owner_name:)
    users_to_notify.each do |workspace_user|
      WorkspaceMailer.workspace_deleted(
        user: workspace_user,
        workspace_name:,
        workspace_owner_name:
      ).deliver_now
    rescue StandardError => e
      Rails.logger.error("Workspace delete notification failed for user #{workspace_user.id}: #{e.class} #{e.message}")
    end
  end

  def deliver_account_deletion_confirmation!(email:)
    AccountMailer.account_deletion_confirmed(user_email: email).deliver_now
  rescue StandardError => e
    Rails.logger.error("Account deletion confirmation email failed for #{email}: #{e.class} #{e.message}")
  end

  def deliver_workspace_transfer_emails!(transferred_workspaces:, deleted_user_name:)
    transferred_workspaces.each do |transfer|
      WorkspaceMailer.workspace_owner_transferred(
        new_owner: transfer[:new_owner],
        workspace: transfer[:workspace],
        previous_owner_name: deleted_user_name
      ).deliver_now
    rescue StandardError => e
      workspace_id = transfer[:workspace].id
      Rails.logger.error(
        "Workspace ownership transfer email failed for workspace #{workspace_id}: #{e.class} #{e.message}"
      )
    end
  end

  def success
    Result.new(success?: true)
  end

  def failure(error_key)
    Result.new(success?: false, error_key:)
  end
end # rubocop:enable Metrics/ClassLength
