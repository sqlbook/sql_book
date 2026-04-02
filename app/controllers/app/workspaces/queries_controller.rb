# frozen_string_literal: true

module App
  module Workspaces
    class QueriesController < ApplicationController
      before_action :require_authentication!
      before_action :set_workspace

      attr_reader :workspace

      def index
        @queries = queries
        @data_sources = data_sources
        @visible_columns = current_user.query_library_visible_columns

        return unless data_sources.empty?
        return unless can_manage_data_sources?(workspace:)

        redirect_to new_app_workspace_data_source_path(workspace)
      end

      def update_visible_columns
        current_user.update_query_library_visible_columns!(columns: visible_columns_params)

        respond_to do |format|
          format.json { render json: { visible_columns: current_user.query_library_visible_columns } }
          format.html { redirect_to app_workspace_queries_path(workspace, search: params[:search]) }
        end
      end

      private

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def set_workspace
        @workspace = find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end

      def queries
        data_source_id = data_sources.select(:id)
        queries = Query.where(data_source_id:, saved: true)
        queries = queries.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
        queries
      end

      def visible_columns_params
        params.fetch(:visible_columns, [])
      end
    end
  end
end
