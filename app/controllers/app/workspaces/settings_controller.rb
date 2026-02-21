# frozen_string_literal: true

module App
  module Workspaces
    class SettingsController < ApplicationController
      before_action :require_authentication!
      before_action :authorize_workspace_settings_access!

      def show
        @workspace = workspace
      end

      def update
        workspace.update(name: workspace_params[:name])
        redirect_to app_workspace_settings_path(workspace, tab: 'general')
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :id)
      end

      def workspace_params
        params.permit(:name)
      end

      def authorize_workspace_settings_access!
        return if can_manage_workspace_settings?(workspace:)

        deny_workspace_access!(workspace:, fallback_path: app_workspace_path(workspace))
      end
    end
  end
end
