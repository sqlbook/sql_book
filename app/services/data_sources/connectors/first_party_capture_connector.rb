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

      def execute_readonly(sql:, statement_timeout_ms: nil, max_rows: nil) # rubocop:disable Lint/UnusedMethodArgument
        old_config = EventRecord.connection_db_config.configuration_hash.dup

        EventRecord.establish_connection(readonly_config(old_config))
        execute_query_in_readonly_transaction(sql:, statement_timeout_ms:)
      ensure
        EventRecord.establish_connection(old_config)
      end

      private

      def readonly_config(old_config)
        old_config.merge(username: readonly_username, password: readonly_password)
      end

      def execute_query_in_readonly_transaction(sql:, statement_timeout_ms:)
        EventRecord.transaction do
          EventRecord.connection.exec_query('SET TRANSACTION READ ONLY')
          EventRecord.connection.exec_query(
            "SET LOCAL app.current_data_source_uuid = '#{data_source.external_uuid}'"
          )
          apply_statement_timeout(statement_timeout_ms)
          EventRecord.connection.exec_query(sql)
        end
      end

      def apply_statement_timeout(statement_timeout_ms)
        return if statement_timeout_ms.blank?

        EventRecord.connection.exec_query(
          "SET LOCAL statement_timeout = '#{statement_timeout_ms}ms'"
        )
      end

      def readonly_username
        'sqlbook_readonly'
      end

      def readonly_password
        ENV.fetch('POSTGRES_READONLY_PASSWORD', 'password')
      end
    end
  end
end
