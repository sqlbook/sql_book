# frozen_string_literal: true

module Api
  module V1
    class QueriesController < Api::BaseController
      def index
        execute_tool(
          action_type: 'query.list',
          payload: {
            'search' => params[:search].to_s.presence,
            'data_source_id' => params[:data_source_id].presence&.to_i
          }.compact
        )
      end

      def run
        execute_tool(
          action_type: 'query.run',
          payload: run_payload
        )
      end

      def create
        execute_tool(
          action_type: 'query.save',
          payload: save_payload
        )
      end

      def update
        execute_tool(
          action_type: update_action_type,
          payload: update_payload
        )
      end

      def destroy
        execute_tool(
          action_type: 'query.delete',
          payload: delete_payload
        )
      end

      private

      def run_payload
        query_request_payload.merge(data_source_reference_payload).compact
      end

      def save_payload
        query_save_payload
          .merge(data_source_reference_payload)
          .merge(query_name_payload)
          .compact
      end

      def query_request_payload
        {
          'question' => params[:question].presence || params[:sql].to_s
        }
      end

      def query_save_payload
        {
          'sql' => params[:sql].to_s,
          'question' => params[:question].to_s.presence
        }
      end

      def data_source_reference_payload
        {
          'data_source_id' => params[:data_source_id].presence&.to_i,
          'data_source_name' => params[:data_source_name].to_s.presence
        }
      end

      def query_name_payload
        {
          'name' => params[:name].to_s.presence
        }
      end

      def update_action_type
        return 'query.rename' if params[:sql].blank?

        'query.update'
      end

      def update_payload
        {
          'query_id' => params[:id].to_i,
          'sql' => params[:sql].to_s.presence,
          'name' => params[:name].to_s.presence
        }.compact
      end

      def delete_payload
        { 'query_id' => params[:id].to_i }
      end
    end
  end
end
