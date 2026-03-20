# frozen_string_literal: true

module App
  module Workspaces
    module DataSourcesHelper
      include ActiveSupport::NumberHelper

      def data_sources_index_sections(data_sources)
        [
          {
            key: :external_database,
            title: I18n.t('app.workspaces.data_sources.index.sections.external_database.title'),
            description: I18n.t('app.workspaces.data_sources.index.sections.external_database.description'),
            headers: [
              I18n.t('app.workspaces.data_sources.index.columns.name'),
              I18n.t('app.workspaces.data_sources.index.columns.type'),
              I18n.t('app.workspaces.data_sources.index.columns.tables'),
              I18n.t('app.workspaces.data_sources.index.columns.related_queries')
            ],
            rows: data_sources.select(&:external_database?),
            row_partial: 'external_database_row',
            empty_title: I18n.t('app.workspaces.data_sources.index.empty.external_database.title'),
            empty_body: I18n.t('app.workspaces.data_sources.index.empty.external_database.body'),
            empty_cta: I18n.t('common.actions.create_new')
          },
          {
            key: :first_party_capture,
            title: I18n.t('app.workspaces.data_sources.index.sections.first_party_capture.title'),
            description: I18n.t('app.workspaces.data_sources.index.sections.first_party_capture.description'),
            headers: [
              I18n.t('app.workspaces.data_sources.index.columns.name'),
              I18n.t('app.workspaces.data_sources.index.columns.total_events'),
              I18n.t('app.workspaces.data_sources.index.columns.events_this_month'),
              I18n.t('app.workspaces.data_sources.index.columns.related_queries')
            ],
            rows: data_sources.select(&:capture_source?),
            row_partial: 'capture_source_row',
            empty_title: I18n.t('app.workspaces.data_sources.index.empty.first_party_capture.title'),
            empty_body: I18n.t('app.workspaces.data_sources.index.empty.first_party_capture.body'),
            empty_cta: I18n.t('common.actions.create_new')
          },
          {
            key: :third_party_data_library,
            title: I18n.t('app.workspaces.data_sources.index.sections.third_party_data_library.title'),
            description: I18n.t('app.workspaces.data_sources.index.sections.third_party_data_library.description'),
            coming_soon: true,
            coming_soon_title: I18n.t('app.workspaces.data_sources.index.coming_soon.title'),
            coming_soon_body: I18n.t('app.workspaces.data_sources.index.coming_soon.body')
          }
        ]
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
            description: I18n.t('app.workspaces.data_sources.new.source_types.external_database.description'),
            selected: selected_source_type.to_s == 'postgres'
          },
          {
            value: 'first_party_capture',
            label: I18n.t('app.workspaces.data_sources.new.source_types.first_party_capture.title'),
            description: I18n.t('app.workspaces.data_sources.new.source_types.first_party_capture.description'),
            coming_soon: true,
            disabled: true
          },
          {
            value: 'third_party_data_library',
            label: I18n.t('app.workspaces.data_sources.new.source_types.third_party_data_library.title'),
            description: I18n.t('app.workspaces.data_sources.new.source_types.third_party_data_library.description'),
            coming_soon: true,
            disabled: true
          }
        ]
      end

      def wizard_database_type_options(selected_database_type: 'postgres')
        [
          {
            value: 'postgres',
            label: I18n.t('app.workspaces.data_sources.new.database_types.postgres'),
            selected: selected_database_type.to_s == 'postgres'
          }
        ]
      end

      def wizard_available_table_groups(available_tables)
        Array(available_tables).map do |group|
          schema = group[:schema] || group['schema']
          tables = Array(group[:tables] || group['tables']).map do |table|
            table_name = table[:name] || table['name']
            qualified_name = table[:qualified_name] || table['qualified_name'] || [schema, table_name].join('.')

            {
              name: table_name,
              qualified_name: qualified_name,
              columns: Array(table[:columns] || table['columns'])
            }
          end

          {
            schema: schema,
            tables: tables
          }
        end
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
        return app_workspace_data_source_queries_path(workspace, data_source) unless query

        app_workspace_data_source_query_path(workspace, data_source, query)
      end

      def query_form_method(query: nil)
        return :put if query

        :post
      end

      def script_base_url
        "#{Rails.application.config.x.app_protocol}://#{Rails.application.config.x.app_host}/assets/script.js?"
      end

      def script_websocket_url
        websocket_protocol = Rails.application.config.x.app_protocol == 'https' ? 'wss' : 'ws'
        "#{websocket_protocol}://#{Rails.application.config.x.app_host}/events/in"
      end
    end
  end
end
