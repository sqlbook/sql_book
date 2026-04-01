# frozen_string_literal: true

module Api
  module V1
    class QueryVisualizationsController < Api::BaseController
      before_action :ensure_visualization_read_access!, only: %i[index show]
      before_action :ensure_visualization_write_access!, only: %i[update destroy]

      def index
        render json: {
          status: 'executed',
          code: 'visualization.loaded',
          data: {
            'visualizations' => serialized_visualizations
          }
        }
      end

      def show
        render json: {
          status: 'executed',
          code: 'visualization.loaded',
          data: {
            'visualization' => serialized_visualization(query.visualizations.find_by(chart_type:))
          }
        }
      end

      def update
        result = Visualizations::UpsertService.new(
          query:,
          workspace:,
          chart_type:,
          attributes: visualization_params
        ).call

        render json: {
          status: result.success? ? 'executed' : 'validation_error',
          code: result.code,
          message: result.message,
          data: {
            'visualization' => serialized_visualization(result.visualization)
          }.compact
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      def destroy
        result = Visualizations::DestroyService.new(query:, chart_type:).call

        render json: {
          status: 'executed',
          code: result.code,
          data: {
            'query_id' => query.id,
            'chart_type' => chart_type
          }
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

      def chart_type
        params[:chart_type].to_s
      end

      def serialized_visualizations
        query.visualizations.order(:chart_type).map do |visualization|
          serialized_visualization(visualization)
        end
      end

      def serialized_visualization(visualization)
        Visualizations::Serializer.call(
          query:,
          visualization:,
          include_preview: true
        )
      end
    end
  end
end
