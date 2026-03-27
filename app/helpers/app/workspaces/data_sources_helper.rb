# frozen_string_literal: true

module App
  module Workspaces
    module DataSourcesHelper # rubocop:disable Metrics/ModuleLength
      include ActiveSupport::NumberHelper

      def data_sources_index_sections(data_sources)
        [
          external_database_section(data_sources),
          first_party_capture_section(data_sources)
        ].compact
      end

      def data_source_index_type_label(data_source)
        case data_source.source_type
        when 'postgres'
          I18n.t('app.workspaces.data_sources.index.types.postgres')
        when 'first_party_capture'
          I18n.t('app.workspaces.data_sources.index.types.first_party_capture')
        else
          data_source.source_type.humanize
        end
      end

      def data_source_index_status_badge(data_source, stats:)
        status = stats.status_for(data_source: data_source)

        case status
        when 'action_required'
          {
            label: I18n.t('app.workspaces.data_sources.index.statuses.action_required'),
            icon_class: 'ri-error-warning-line',
            modifier: 'warning'
          }
        when 'error'
          {
            label: I18n.t('app.workspaces.data_sources.index.statuses.error'),
            icon_class: 'ri-alert-line',
            modifier: 'error'
          }
        when 'pending_setup'
          {
            label: I18n.t('app.workspaces.data_sources.index.statuses.pending_setup'),
            icon_class: 'ri-time-line',
            modifier: 'pending'
          }
        end
      end

      def wizard_source_type_options(selected_source_type: 'postgres')
        [
          {
            value: 'postgres',
            label: I18n.t('app.workspaces.data_sources.new.source_types.external_database.title'),
            selected: selected_source_type.to_s == 'postgres'
          },
          {
            value: 'first_party_capture',
            label: I18n.t('app.workspaces.data_sources.new.source_types.first_party_capture.title'),
            coming_soon: true,
            disabled: true
          },
          {
            value: 'third_party_data_library',
            label: I18n.t('app.workspaces.data_sources.new.source_types.third_party_data_library.title'),
            coming_soon: true,
            disabled: true
          }
        ]
      end

      def wizard_database_type_options
        %w[
          postgres
          mysql
          sql_server
          mariadb
          oracle
          snowflake
          redshift
          bigquery
          clickhouse
          databricks
          sql_anywhere
          athena
        ].map do |database_type|
          {
            value: database_type,
            label: I18n.t("app.workspaces.data_sources.new.database_types.#{database_type}")
          }
        end
      end

      def wizard_available_table_groups(available_tables)
        Array(available_tables).map { |group| normalized_table_group(group) }
      end

      def tracking_code(data_source:)
        <<~HTML
          <script>
            (function(s,q,l,b,o,o,k){
              s._sbSettings={uuid:'#{data_source.external_uuid}',websocketUrl:'#{script_websocket_url}'};
              e=q.getElementsByTagName('head')[0];
              a=q.createElement('script');
              a.src=l+s._sbSettings.uuid;
              e.appendChild(a);
            })(window,document,'#{script_base_url}');
          </script>
        HTML
      end

      def verifying?
        params['verifying'].present?
      end

      def verification_failed?
        params[:verification_attempt].to_i >= 5
      end

      def query_form_path(workspace:, data_source:, query: nil)
        return app_workspace_data_source_queries_path(workspace, data_source) unless query&.persisted?

        app_workspace_data_source_query_path(workspace, data_source, query)
      end

      def query_form_method(query: nil)
        return :put if query&.persisted?

        :post
      end

      def script_base_url
        "#{Rails.application.config.x.app_protocol}://#{Rails.application.config.x.app_host}/assets/script.js?"
      end

      def script_websocket_url
        websocket_protocol = Rails.application.config.x.app_protocol == 'https' ? 'wss' : 'ws'
        "#{websocket_protocol}://#{Rails.application.config.x.app_host}/events/in"
      end

      private

      def external_database_section(data_sources)
        rows = data_sources.select(&:external_database?)
        return if rows.empty?

        build_index_section(
          key: :external_database,
          section_scope: 'external_database',
          headers: %w[name type tables related_queries],
          rows:,
          row_partial: 'external_database_row'
        )
      end

      def first_party_capture_section(data_sources)
        rows = data_sources.select(&:capture_source?)
        return if rows.empty?

        build_index_section(
          key: :first_party_capture,
          section_scope: 'first_party_capture',
          headers: %w[name total_events events_this_month related_queries],
          rows:,
          row_partial: 'capture_source_row'
        )
      end

      def build_index_section(key:, section_scope:, headers:, rows:, row_partial:)
        {
          key:,
          title: I18n.t("app.workspaces.data_sources.index.sections.#{section_scope}.title"),
          headers: translated_headers(headers),
          rows:,
          row_partial:
        }
      end

      def translated_headers(keys)
        keys.map { |key| I18n.t("app.workspaces.data_sources.index.columns.#{key}") }
      end

      def normalized_table_group(group)
        schema = value_from(group, :schema)

        {
          schema:,
          tables: Array(value_from(group, :tables)).map do |table|
            normalized_table_entry(schema:, table:)
          end
        }
      end

      def normalized_table_entry(schema:, table:)
        table_name = value_from(table, :name)
        qualified_name = value_from(table, :qualified_name) || [schema, table_name].join('.')

        {
          name: table_name,
          qualified_name:,
          columns: Array(value_from(table, :columns))
        }
      end

      def value_from(object, key)
        object[key] || object[key.to_s]
      end
    end
  end
end
