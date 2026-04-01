# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class QueriesController < ApplicationController # rubocop:disable Metrics/ClassLength
        before_action :require_authentication!
        before_action :authorize_query_destroy_access!, only: %i[destroy]
        before_action :prepare_query_editor, only: %i[index show]

        def index
          @query = Query.new(
            query: params[:query].to_s.presence,
            name: params[:name].to_s.presence,
            data_source:
          )
          @query_editor_state = build_query_editor_state(query: @query)
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
          @query_editor_state = build_query_editor_state(query: @query, query_chat_source: @query_chat_source)
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

        def build_query_editor_state(query:, query_chat_source: nil)
          QueryEditor::StateBuilder.call(
            workspace:,
            query:,
            data_source: query.data_source || data_source,
            query_chat_source:,
            active_tab: params[:tab]
          )
        end
      end # rubocop:enable Metrics/ClassLength
    end
  end
end
