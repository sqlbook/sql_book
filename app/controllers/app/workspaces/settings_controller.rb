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
        if update_workspace_name
          redirect_to_general_with_toast(workspace_updated_toast)
        else
          redirect_to_general_with_toast(workspace_update_failed_toast)
        end
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

      def update_workspace_name
        workspace.update!(name: workspace_params[:name])
      rescue StandardError => e
        Rails.logger.error("Workspace settings update failed: #{e.class} #{e.message}")
        false
      end

      def redirect_to_general_with_toast(toast)
        flash[:toast] = toast
        redirect_to app_workspace_settings_path(workspace, tab: 'general')
      end

      def workspace_updated_toast
        {
          type: 'success',
          title: I18n.t('toasts.workspaces.updated.title'),
          body: I18n.t('toasts.workspaces.updated.body')
        }
      end

      def workspace_update_failed_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.update_failed.title'),
          body: I18n.t('toasts.workspaces.update_failed.body')
        }
      end
    end
  end
end
