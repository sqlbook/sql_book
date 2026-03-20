# frozen_string_literal: true

module DataSources
  module Connectors
    class FirstPartyCaptureConnector < BaseConnector
      def validate_connection!
        true
      end

      def list_tables(**)
        [{
          schema: 'events',
          tables: EventRecord.all_event_types.map do |model|
            {
              name: model.table_name,
              qualified_name: "events.#{model.table_name}",
              columns: model.columns.map do |column|
                {
                  name: column.name,
                  data_type: column.sql_type_metadata.sql_type,
                  default: column.default
                }
              end
            }
          end
        }]
      end

      def execute_readonly(sql:, statement_timeout_ms: nil, max_rows: nil)
        old_config = EventRecord.connection_db_config.configuration_hash.dup
        readonly_config = old_config.merge(username: readonly_username, password: readonly_password)

        EventRecord.establish_connection(readonly_config)
        EventRecord.transaction do
          EventRecord.connection.exec_query('SET TRANSACTION READ ONLY')
          EventRecord.connection.exec_query("SET LOCAL app.current_data_source_uuid = '#{data_source.external_uuid}'")
          EventRecord.connection.exec_query("SET LOCAL statement_timeout = '#{statement_timeout_ms}ms'") if statement_timeout_ms.present?
          EventRecord.connection.exec_query(sql)
        end
      ensure
        EventRecord.establish_connection(old_config)
      end

      private

      def readonly_username
        'sqlbook_readonly'
      end

      def readonly_password
        ENV.fetch('POSTGRES_READONLY_PASSWORD', 'password')
      end
    end
  end
end
