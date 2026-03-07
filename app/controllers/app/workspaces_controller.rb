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
      @chat_thread = ChatThread.active_for(workspace:, user: current_user)
      @chat_messages = @chat_thread.chat_messages.includes(:user, { images_attachments: :blob }, :chat_action_requests)
      @chat_action_requests_by_id = @chat_thread.chat_action_requests.index_by(&:id)
      @chat_suggestions = [
        I18n.t('app.workspaces.chat.suggestions.invite_team_mates'),
        I18n.t('app.workspaces.chat.suggestions.rename_workspace'),
        I18n.t('app.workspaces.chat.suggestions.list_team_members')
      ]
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

      deletion_result = WorkspaceDeletionService.new(workspace:, deleted_by: current_user).call
      return handle_workspace_delete_error unless deletion_result.success?

      failed_notifications = deletion_result.failed_notifications

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

    def delete_workspace_toast(failed_notifications:)
      if failed_notifications.zero?
        return {
          type: 'success',
          title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
          body: I18n.t('toasts.workspaces.deleted.body')
        }
      end

      {
        type: 'information',
        title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
        body: I18n.t('toasts.workspaces.deleted_partial.body')
      }
    end

    def handle_workspace_delete_error
      flash[:toast] = generic_error_toast
      redirect_to forbidden_delete_redirect_path
    end
  end
end
