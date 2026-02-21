# frozen_string_literal: true

module App
  class WorkspacesController < ApplicationController
    before_action :require_authentication!

    def index
      @workspaces = workspaces
      return redirect_to new_app_workspace_path if workspaces.empty?

      @workspaces_stats = WorkspacesStatsService.new(workspaces:)
    end

    def show
      @workspace = workspace
    end

    def new; end

    def create
      return redirect_to new_app_workspace_path unless workspace_params[:name]

      workspace = create_workspace!
      create_owner!(workspace:)

      # This is their only workspace so they should create a datasource
      return redirect_to new_app_workspace_data_source_path(workspace) if current_user.workspaces.size == 1

      redirect_to app_workspaces_path
    end

    def destroy
      return handle_forbidden_workspace_delete unless current_user_owner?

      users_to_notify = workspace_users_to_notify
      workspace_name = workspace.name
      deleted_by_name = current_user.full_name

      workspace.destroy!
      failed_notifications = notify_workspace_deleted_users!(
        users: users_to_notify,
        workspace_name: workspace_name,
        workspace_owner_name: deleted_by_name
      )

      flash[:toast] = delete_workspace_toast(failed_notifications:)
      redirect_to app_workspaces_path
    end

    private

    def workspaces
      @workspaces ||= current_user.workspaces
    end

    def workspace
      @workspace ||= find_workspace_for_current_user!(param_key: :id)
    end

    def workspace_params
      params.permit(:name)
    end

    def create_workspace!
      Workspace.create!(name: workspace_params[:name])
    end

    def create_owner!(workspace:)
      Member.create!(
        user: current_user,
        workspace:,
        role: Member::Roles::OWNER,
        status: Member::Status::ACCEPTED
      )
    end

    def current_user_owner?
      workspace.role_for(user: current_user) == Member::Roles::OWNER
    end

    def handle_forbidden_workspace_delete
      flash[:toast] = {
        type: 'error',
        title: I18n.t('toasts.workspaces.delete_forbidden.title'),
        body: I18n.t('toasts.workspaces.delete_forbidden.body')
      }
      redirect_to(forbidden_delete_redirect_path)
    end

    def forbidden_delete_redirect_path
      return app_workspace_settings_path(workspace, tab: 'general') if can_manage_workspace_settings?(workspace:)

      app_workspace_path(workspace)
    end

    def workspace_users_to_notify
      workspace.members.includes(:user).map(&:user).uniq.reject { |user| user.id == current_user.id }
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

    def delete_workspace_toast(failed_notifications:)
      if failed_notifications.zero?
        return {
          type: 'success',
          title: I18n.t('toasts.workspaces.deleted.title'),
          body: I18n.t('toasts.workspaces.deleted.body')
        }
      end

      {
        type: 'information',
        title: I18n.t('toasts.workspaces.deleted_partial.title'),
        body: I18n.t('toasts.workspaces.deleted_partial.body')
      }
    end
  end
end
