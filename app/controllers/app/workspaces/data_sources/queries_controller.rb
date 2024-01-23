# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class QueriesController < ApplicationController
        before_action :require_authentication!

        def index
          @workspace = workspace
          @data_sources = data_sources
          @data_source = data_source
        end

        def show
          query.update(last_run_at: Time.current)
          @query = query
        end

        def create
          query = Query.create(
            query: query_params[:query],
            author: current_user,
            data_source:
          )
          redirect_to app_workspace_data_source_query_path(workspace, data_source, query)
        end

        def update
          return handle_update_query_name if query_params[:name].present?
          return handle_update_query_query if query_params[:query].present?

          redirect_to app_workspace_data_source_query_path(workspace, data_source, query)
        end

        private

        def workspace
          @workspace ||= current_user.workspaces.find(params[:workspace_id])
        end

        def data_sources
          @data_sources ||= workspace.data_sources
        end

        def data_source
          @data_source ||= data_sources.find(params[:data_source_id])
        end

        def query
          Query.find_by!(id: params[:id], data_source_id: data_source.id)
        end

        def query_params
          params.permit(
            :data_source_id,
            :query,
            :name,
            :action,
            :authenticity_token
          )
        end

        def handle_update_query_name
          query.update!(
            saved: true,
            name: query_params[:name],
            last_updated_by: current_user
          )
          redirect_to app_workspace_data_source_query_path(workspace, data_source, query, tab: 'settings')
        end

        # TODO: Don't update if the query doesn't change
        def handle_update_query_query
          query.update!(
            query: query_params[:query],
            last_updated_by: current_user
          )
          redirect_to app_workspace_data_source_query_path(workspace, data_source, query)
        end
      end
    end
  end
end
