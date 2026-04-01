# frozen_string_literal: true

module App
  module Workspaces
    module Settings
      class VisualizationThemesController < ApplicationController
        before_action :require_authentication!
        before_action :authorize_workspace_settings_access!

        def create
          result = Visualizations::ThemeUpsertService.new(
            workspace:,
            attributes: theme_params
          ).call

          redirect_with_result(result:, success_key: 'app.workspaces.settings.branding.toasts.theme_saved')
        end

        def update
          result = Visualizations::ThemeUpsertService.new(
            workspace:,
            theme: theme,
            attributes: theme_params
          ).call

          redirect_with_result(
            result:,
            success_key: 'app.workspaces.settings.branding.toasts.theme_saved',
            theme_reference: theme.reference_key
          )
        end

        def destroy
          result = Visualizations::ThemeDeleteService.new(theme:).call
          redirect_with_result(result:, success_key: 'app.workspaces.settings.branding.toasts.theme_deleted')
        end

        def duplicate
          source_theme = Visualizations::ThemeLibraryService.find_entry(
            workspace:,
            reference: params[:reference]
          )
          result = Visualizations::ThemeDuplicateService.new(workspace:, source_theme:).call

          redirect_with_result(
            result:,
            success_key: 'app.workspaces.settings.branding.toasts.theme_duplicated',
            theme_reference: result.theme&.reference_key
          )
        end

        def set_default
          result = Visualizations::ThemeDefaultService.new(theme:).call
          redirect_with_result(
            result:,
            success_key: 'app.workspaces.settings.branding.toasts.theme_defaulted',
            theme_reference: theme.reference_key
          )
        end

        private

        def workspace
          @workspace ||= find_workspace_for_current_user!(param_key: :id)
        end

        def theme
          @theme ||= workspace.visualization_themes.find(params[:theme_id])
        end

        def theme_params
          params.permit(
            :name,
            :default,
            :raw_json_dark,
            :raw_json_light,
            theme_json_dark: {},
            theme_json_light: {},
            editor_dark: {},
            editor_light: {}
          )
        end

        def authorize_workspace_settings_access!
          return if can_manage_workspace_settings?(workspace:)

          deny_workspace_access!(workspace:, fallback_path: app_workspace_path(workspace))
        end

        def redirect_with_result(result:, success_key:, theme_reference: nil)
          flash[:toast] = toast_for(result:, success_key:)

          redirect_to app_workspace_settings_path(
            workspace,
            tab: 'branding',
            theme: theme_reference.presence || theme_param_for(result:)
          )
        end

        def toast_for(result:, success_key:)
          if result.success?
            {
              type: 'success',
              title: I18n.t("#{success_key}.title"),
              body: I18n.t("#{success_key}.body")
            }
          else
            {
              type: 'error',
              title: I18n.t('app.workspaces.settings.branding.toasts.theme_failed.title'),
              body: result.message.presence || I18n.t('app.workspaces.settings.branding.toasts.theme_failed.body')
            }
          end
        end

        def theme_param_for(result)
          result.respond_to?(:theme) ? result.theme&.reference_key : nil
        end
      end
    end
  end
end
