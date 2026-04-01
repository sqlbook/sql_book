# frozen_string_literal: true

module App
  module Workspaces
    class QueryEditorController < ApplicationController
      before_action :require_authentication!
      before_action :authorize_query_write_access!

      def run
        result = QueryEditor::RunService.new(workspace:, actor: current_user, attributes: editor_params).call
        render_editor_response(result:, data: run_response_data(result))
      end

      def save
        result = QueryEditor::SaveService.new(workspace:, actor: current_user, attributes: editor_params).call
        render_editor_response(result:, data: save_response_data(result))
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def editor_params
        params.permit(
          :query_id,
          :data_source_id,
          :name,
          :sql,
          :run_token,
          :request_generated_name,
          visualizations: [
            :chart_type,
            :theme_reference,
            :appearance_raw_json_dark,
            :appearance_raw_json_light,
            { data_config: {} },
            { other_config: {} },
            { appearance_config_dark: {} },
            { appearance_config_light: {} },
            { appearance_editor_dark: {} },
            { appearance_editor_light: {} }
          ]
        )
      end

      def authorize_query_write_access!
        return if can_write_queries?(workspace:)

        deny_workspace_access!(workspace:)
      end

      def render_editor_response(result:, data:)
        render json: {
          status: result.success? ? 'executed' : 'validation_error',
          code: result.code,
          message: result.message,
          data:
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      def run_response_data(result)
        {
          'result' => serialized_query_result(result.query_result),
          'generated_name' => result.generated_name,
          'run_token' => result.run_token,
          'data_source_id' => result.data_source&.id
        }.compact
      end

      def save_response_data(result)
        {
          'query' => serialized_query(result.query),
          'save_outcome' => result.save_outcome,
          'conflicting_query' => serialized_query(result.conflicting_query)
        }.compact
      end

      def serialized_query(query)
        return nil unless query

        {
          'id' => query.id,
          'name' => query.name,
          'sql' => query.query,
          'saved' => query.saved,
          'data_source_id' => query.data_source_id,
          'canonical_path' => app_workspace_data_source_query_path(workspace, query.data_source, query),
          'visualization_types' => query.visualizations.order(:chart_type).pluck(:chart_type)
        }
      end

      def serialized_query_result(query_result)
        return nil unless query_result

        {
          'error' => query_result.error,
          'error_message' => query_result.error_message,
          'columns' => query_result.columns,
          'rows' => query_result.rows,
          'row_count' => query_result.rows.length
        }
      end
    end
  end
end
