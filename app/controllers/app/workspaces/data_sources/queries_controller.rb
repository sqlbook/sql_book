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
          query.update(query_update_params)

          redirect_to app_workspace_data_source_query_path(workspace, data_source, query, tab: query_redirect_tab)
        end

        def chart_config
          query.update(query_chart_config_params)

          redirect_to app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
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
          params.permit(:chart_type, :query, :name)
        end

        def chart_config_params # rubocop:disable Metrics/MethodLength
          params.permit(
            :x_axis_key,
            :x_axis_label,
            :x_axis_label_enabled,
            :x_axis_gridlines_enabled,
            :y_axis_key,
            :y_axis_label,
            :y_axis_label_enabled,
            :y_axis_gridlines_enabled,
            :title,
            :title_enabled,
            :subtitle,
            :subtitle_enabled,
            :legend_enabled,
            :legend_position,
            :legend_alignment,
            :tooltips_enabled,
            :data_column,
            :post_text_label_enabled,
            :post_text_label,
            :post_text_label_position,
            colors: []
          )
        end

        def query_update_params
          params = {}
          # TODO: Skip update if the query has not changed
          params.merge!(query_params)
          params[:last_updated_by] = current_user
          params[:saved] = true if query_params[:name]

          params
        end

        def query_chart_config_params
          params = {}

          params[:last_updated_by] = current_user
          params[:chart_config] = chart_config_params

          params
        end

        def query_redirect_tab
          return 'settings' if query_params[:name]
          return 'visualization' if query_params[:chart_type]

          nil
        end
      end
    end
  end
end
