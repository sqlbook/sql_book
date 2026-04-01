# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class QueryVisualizationsController < ApplicationController
        before_action :require_authentication!
        before_action :authorize_query_write_access!, only: %i[show update destroy]

        def show
          render json: {
            status: 'executed',
            code: 'visualization.loaded',
            data: {
              'visualization' => serialized_visualization(query.visualizations.find_by(chart_type: chart_type))
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

        def workspace
          @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
        end

        def data_source
          @data_source ||= workspace.data_sources.find(params[:data_source_id])
        end

        def query
          @query ||= Query.find_by!(id: params[:query_id], data_source_id: data_source.id)
        end

        def visualization_params
          params.permit(
            :theme_reference,
            :appearance_raw_json_dark,
            :appearance_raw_json_light,
            data_config: {},
            other_config: {},
            appearance_config_dark: {},
            appearance_config_light: {},
            appearance_editor_dark: {},
            appearance_editor_light: {}
          )
        end

        def authorize_query_write_access!
          return if can_write_queries?(workspace:)

          deny_workspace_access!(workspace:)
        end

        def chart_type
          params[:chart_type].to_s
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
end
