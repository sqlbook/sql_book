# frozen_string_literal: true

module Api
  module V1
    class VisualizationThemesController < Api::BaseController
      before_action :ensure_theme_read_access!, only: %i[index show]
      before_action :ensure_theme_write_access!, only: %i[create update destroy duplicate set_default]

      def index
        render json: {
          status: 'executed',
          code: 'visualization_theme.listed',
          data: {
            'themes' => Visualizations::ThemeLibraryService.call(workspace:).map do |theme|
              Visualizations::ThemeSerializer.call(theme:)
            end
          }
        }
      end

      def show
        render json: {
          status: 'executed',
          code: 'visualization_theme.loaded',
          data: {
            'theme' => Visualizations::ThemeSerializer.call(theme: theme_entry)
          }
        }
      end

      def create
        result = Visualizations::ThemeUpsertService.new(
          workspace:,
          attributes: theme_params
        ).call

        render_theme_result(result:)
      end

      def update
        result = Visualizations::ThemeUpsertService.new(
          workspace:,
          theme: theme,
          attributes: theme_params
        ).call

        render_theme_result(result:)
      end

      def destroy
        result = Visualizations::ThemeDeleteService.new(theme:).call

        render json: {
          status: result.success? ? 'executed' : 'validation_error',
          code: result.code,
          message: result.message,
          data: result.success? ? { 'deleted_theme_id' => theme.id } : {}
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      def duplicate
        source = theme_entry
        result = Visualizations::ThemeDuplicateService.new(workspace:, source_theme: source).call
        render_theme_result(result:)
      end

      def set_default
        result = Visualizations::ThemeDefaultService.new(theme:).call
        render_theme_result(result:)
      end

      private

      def theme
        @theme ||= workspace.visualization_themes.find(params[:id])
      end

      def theme_entry
        @theme_entry ||= Visualizations::ThemeLibraryService.find_entry(
          workspace:,
          reference: theme_reference_param
        )
      end

      def theme_reference_param
        reference = params[:reference].presence || params[:id].to_s
        return reference if reference == Visualizations::SystemTheme::REFERENCE_KEY
        return reference if reference.start_with?('workspace_theme:')

        "workspace_theme:#{reference}"
      end

      def theme_params
        params.permit(
          :name,
          :default,
          theme_json_dark: {},
          theme_json_light: {}
        )
      end

      def render_theme_result(result:)
        render json: {
          status: result.success? ? 'executed' : 'validation_error',
          code: result.code,
          message: result.message,
          data: result.theme ? { 'theme' => Visualizations::ThemeSerializer.call(theme: result.theme) } : {}
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      def ensure_theme_read_access!
        return if workspace_role_for(workspace:).present?

        render_workspace_unavailable
      end

      def ensure_theme_write_access!
        return if can_manage_workspace_settings?(workspace:)

        render json: {
          status: 'forbidden',
          error_code: 'forbidden_role',
          message: I18n.t('api.v1.visualizations.errors.forbidden')
        }, status: :forbidden
      end
    end
  end
end
