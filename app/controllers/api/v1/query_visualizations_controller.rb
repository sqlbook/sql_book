# frozen_string_literal: true

module Api
  module V1
    class QueryVisualizationsController < Api::BaseController
      before_action :ensure_visualization_read_access!, only: :show
      before_action :ensure_visualization_write_access!, only: %i[update destroy]

      def show
        render json: {
          status: 'executed',
          code: 'visualization.loaded',
          data: {
            'visualization' => Visualizations::Serializer.call(
              query: query,
              visualization: query.visualization,
              include_preview: true
            )
          }
        }
      end

      def update
        result = Visualizations::UpsertService.new(
          query:,
          workspace:,
          attributes: visualization_params
        ).call

        render json: {
          status: result.success? ? 'executed' : 'validation_error',
          code: result.code,
          message: result.message,
          data: {
            'visualization' => result.visualization && Visualizations::Serializer.call(
              query:,
              visualization: result.visualization,
              include_preview: true
            )
          }.compact
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      def destroy
        result = Visualizations::DestroyService.new(query:).call

        render json: {
          status: 'executed',
          code: result.code,
          data: { 'query_id' => query.id }
        }
      end

      private

      def query
        @query ||= Query.joins(:data_source)
          .where(data_sources: { workspace_id: workspace.id })
          .find(params[:query_id])
      end

      def visualization_params
        params.permit(
          :chart_type,
          :theme_reference,
          data_config: {},
          other_config: {},
          appearance_config_dark: {},
          appearance_config_light: {}
        )
      end

      def ensure_visualization_read_access!
        return if workspace_role_for(workspace:).present?

        render_workspace_unavailable
      end

      def ensure_visualization_write_access!
        return if can_write_queries?(workspace:)

        render json: {
          status: 'forbidden',
          error_code: 'forbidden_role',
          message: I18n.t('api.v1.visualizations.errors.forbidden')
        }, status: :forbidden
      end
    end
  end
end
