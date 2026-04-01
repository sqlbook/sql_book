# frozen_string_literal: true

module App
  module Workspaces
    class SettingsController < ApplicationController
      before_action :require_authentication!
      before_action :authorize_workspace_settings_access!

      def show
        @workspace = workspace
        @theme_library = Visualizations::ThemeLibraryService.call(workspace:)
        @selected_theme_reference = selected_theme_reference
        @selected_theme_entry = selected_theme_entry
        @theme_editor_attributes_dark = build_theme_editor_attributes(mode: :dark)
        @theme_editor_attributes_light = build_theme_editor_attributes(mode: :light)
        @theme_preview_dark = build_theme_preview(mode: :dark)
        @theme_preview_light = build_theme_preview(mode: :light)
      end

      def update
        if workspace.update(name: workspace_params[:name])
          redirect_to_general_with_toast(workspace_updated_toast)
        else
          redirect_to_general_with_toast(workspace_update_failed_toast)
        end
      rescue StandardError => e
        Rails.logger.error("Workspace settings update failed: #{e.class} #{e.message}")
        redirect_to_general_with_toast(generic_error_toast)
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :id)
      end

      def workspace_params
        params.permit(:name)
      end

      def selected_theme_reference
        params[:theme].to_s.presence
      end

      def selected_theme_entry
        return theme_seed_for_new_record if selected_theme_reference == 'new'
        return nil unless params[:tab].to_s == 'branding'

        Visualizations::ThemeLibraryService.find_entry(
          workspace:,
          reference: selected_theme_library_reference
        )
      end

      def selected_theme_library_reference
        selected_theme_reference.presence ||
          workspace.default_visualization_theme&.reference_key ||
          Visualizations::SystemTheme::REFERENCE_KEY
      end

      def theme_seed_for_new_record
        workspace.default_visualization_theme || Visualizations::SystemTheme.new(workspace:)
      end

      def build_theme_editor_attributes(mode:)
        theme_json = case mode.to_s
                     when 'light'
                       @selected_theme_entry&.theme_json_light
                     else
                       @selected_theme_entry&.theme_json_dark
                     end

        Visualizations::ThemeFormBuilder.editor_attributes(theme_json: theme_json || {})
      end

      def build_theme_preview(mode:)
        theme_json = case mode.to_s
                     when 'light'
                       @selected_theme_entry&.theme_json_light
                     else
                       @selected_theme_entry&.theme_json_dark
                     end
        return nil if theme_json.blank?

        Visualizations::ThemePreviewBuilder.call(theme_json:)
      end

      def authorize_workspace_settings_access!
        return if can_manage_workspace_settings?(workspace:)

        deny_workspace_access!(workspace:, fallback_path: app_workspace_path(workspace))
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
