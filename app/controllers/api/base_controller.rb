# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    before_action :require_api_authentication!

    rescue_from ApplicationController::WorkspaceAccessDenied, with: :render_workspace_unavailable

    private

    def require_api_authentication!
      return if current_user

      render json: {
        status: 'unauthorized',
        error_code: 'unauthorized',
        message: 'Authentication required'
      }, status: :unauthorized
    end

    def workspace
      @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
    end

    def execute_tool(action_type:, payload:)
      execution = Chat::ActionExecutor.new(workspace:, actor: current_user).execute(
        action_type:,
        payload: payload.merge('workspace_id' => workspace.id)
      )

      render json: {
        status: execution.status,
        code: execution.code,
        fallback_message: execution.fallback_message,
        message: execution.user_message,
        data: execution.data,
        error_code: execution.error_code
      }, status: http_status_for(execution.status)
    end

    def http_status_for(result_status)
      case result_status
      when 'executed' then :ok
      when 'validation_error' then :unprocessable_entity
      when 'forbidden' then :forbidden
      else
        :internal_server_error
      end
    end

    def render_workspace_unavailable
      render json: {
        status: 'forbidden',
        error_code: 'workspace_unavailable',
        message: I18n.t('toasts.workspaces.unavailable.body')
      }, status: :forbidden
    end
  end
end
