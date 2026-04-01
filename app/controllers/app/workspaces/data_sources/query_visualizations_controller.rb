# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class QueryVisualizationsController < ApplicationController
        before_action :require_authentication!
        before_action :authorize_query_write_access!, only: %i[update destroy]

        def update
          result = Visualizations::UpsertService.new(
            query:,
            workspace:,
            attributes: visualization_params
          ).call

          flash[:toast] = failure_toast(result.message) unless result.success?
          redirect_to app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
        end

        def destroy
          Visualizations::DestroyService.new(query:).call
          redirect_to app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
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
            :chart_type,
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

        def failure_toast(message)
          {
            type: 'error',
            title: I18n.t('app.workspaces.visualizations.toasts.save_failed.title'),
            body: message.presence || I18n.t('app.workspaces.visualizations.toasts.save_failed.body')
          }
        end
      end
    end
  end
end
