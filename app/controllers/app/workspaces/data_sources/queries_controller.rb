# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class QueriesController < ApplicationController # rubocop:disable Metrics/ClassLength
        before_action :require_authentication!
        before_action :authorize_query_write_access!, only: %i[create update]
        before_action :authorize_query_destroy_access!, only: %i[destroy]
        before_action :prepare_query_editor, only: %i[index show]

        def index
          @query = Query.new(
            query: params[:query].to_s.presence,
            name: params[:name].to_s.presence,
            data_source:
          )
        end

        def show
          @query = find_query
          raise ActiveRecord::RecordNotFound if @query_lookup_result == :mismatched
          return redirect_to_missing_query unless @query

          @query.update(last_run_at: Time.current)
          @query_chat_source = Queries::ChatSourceResolver.new(
            query: @query,
            viewer: current_user,
            workspace:
          ).call
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
          result = Queries::UpdateService.new(workspace:, actor: current_user, attributes: query_update_payload).call
          reconcile_chat_query_cards!(result:) if result.success? && result.query.present?
          toast = query_update_toast(result:)
          flash[:toast] = toast if toast

          redirect_to query_update_redirect_path(result:)
        end

        def destroy
          query.destroy!
          redirect_to app_workspace_queries_path(workspace)
        end

        private

        def workspace
          @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
        end

        def data_sources
          @data_sources ||= workspace.data_sources
        end

        def data_source
          @data_source ||= data_sources.find(params[:data_source_id])
        end

        def prepare_query_editor
          @workspace = workspace
          @data_sources = data_sources
          @data_source = data_source
          @query_schema_groups = query_schema_groups_for(@data_source)
          @query_schema_options = query_schema_options(@query_schema_groups)
          @default_query_schema = @query_schema_options.first&.last
          @available_visualization_types = Visualizations::ChartRegistry.available
          @visualization_theme_library = Visualizations::ThemeLibraryService.call(workspace:)
        end

        def query_schema_groups_for(selected_data_source)
          tables = selected_data_source.connector.list_tables(
            include_columns: true,
            selected_only: selected_data_source.external_database?
          )

          Array(tables).map { |group| normalized_query_schema_group(group) }
        rescue ::DataSources::Connectors::BaseConnector::ConnectionError
          []
        end

        def query_schema_options(groups)
          groups.flat_map do |group|
            group[:tables].map do |table|
              ["#{group[:schema]}.#{table[:name]}", table[:schema_key]]
            end
          end
        end

        def normalized_query_schema_group(group)
          normalized_group = group.deep_symbolize_keys

          {
            schema: normalized_group[:schema],
            tables: Array(normalized_group[:tables]).map do |table|
              normalized_query_schema_table(group: normalized_group, table:)
            end
          }
        end

        def normalized_query_schema_table(group:, table:)
          normalized_table = table.deep_symbolize_keys
          qualified_name = normalized_table[:qualified_name] || [
            group[:schema],
            normalized_table[:name]
          ].join('.')

          {
            name: normalized_table[:name],
            qualified_name:,
            schema_key: qualified_name.parameterize(separator: '_'),
            columns: Array(normalized_table[:columns]).map(&:deep_symbolize_keys)
          }
        end

        def query
          Query.find_by!(id: params[:id], data_source_id: data_source.id)
        end

        def find_query
          scoped_query = Query.find_by(id: params[:id], data_source_id: data_source.id)
          return scoped_query if scoped_query

          @query_lookup_result = Query.exists?(id: params[:id]) ? :mismatched : :missing
          nil
        end

        def query_params
          params.permit(:query, :name)
        end

        def query_update_payload
          {
            'query_id' => query.id,
            'sql' => query_params[:query].presence,
            'name' => query_params[:name].presence
          }.compact
        end

        def query_redirect_tab
          return 'settings' if query_params[:name]

          nil
        end

        def authorize_query_write_access!
          return if can_write_queries?(workspace:)

          deny_workspace_access!(workspace:)
        end

        def authorize_query_destroy_access!
          return if can_destroy_query?(workspace:, query:)

          deny_workspace_access!(workspace:)
        end

        def redirect_to_missing_query
          flash[:toast] = {
            type: 'error',
            title: I18n.t('toasts.workspaces.queries.missing.title'),
            body: I18n.t('toasts.workspaces.queries.missing.body')
          }
          redirect_to app_workspace_queries_path(workspace)
        end

        def query_update_toast(result:)
          return already_saved_query_toast(result:) if result.success? && result.update_outcome == 'already_saved'
          return if result.success?

          {
            type: 'error',
            title: I18n.t('toasts.workspaces.queries.update_failed.title'),
            body: result.message
          }
        end

        def query_update_redirect_path(result:)
          app_workspace_data_source_query_path(
            workspace,
            data_source,
            redirect_query(result:),
            tab: query_redirect_tab
          )
        end

        def redirect_query(result:)
          return query unless result.success? && result.query.present?

          result.query
        end

        def already_saved_query_toast(result:)
          {
            type: 'info',
            title: I18n.t('toasts.workspaces.queries.already_saved.title'),
            body: I18n.t('toasts.workspaces.queries.already_saved.body', name: result.query.name)
          }
        end

        def reconcile_chat_query_cards!(result:)
          Queries::ChatQueryCardReconciler.new(query: result.query).call
        end
      end # rubocop:enable Metrics/ClassLength
    end
  end
end
