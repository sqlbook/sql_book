# frozen_string_literal: true

require 'pg'

module DataSources
  module Connectors
    class PostgresConnector < BaseConnector # rubocop:disable Metrics/ClassLength
      DEFAULT_STATEMENT_TIMEOUT_MS = 5_000
      DEFAULT_ROW_LIMIT = 1_000
      TABLE_LIMIT = 200

      def initialize(data_source: nil, connection_attributes: {})
        super(data_source:)
        @connection_attributes = connection_attributes.deep_symbolize_keys
      end

      def validate_connection!
        with_connection do |connection|
          connection.exec('SELECT 1')
        end

        true
      rescue PG::Error
        raise ConnectionError, I18n.t('app.workspaces.data_sources.validation.connection_failed')
      end

      def list_tables(limit: TABLE_LIMIT, include_columns: true, selected_only: false)
        with_connection do |connection|
          rows = connection.exec(table_list_sql(limit:))
          filtered_rows = filter_rows(rows:, selected_only:)
          build_table_groups(connection:, rows: filtered_rows, include_columns:)
        end
      rescue PG::Error
        raise ConnectionError, I18n.t('app.workspaces.data_sources.validation.connection_failed')
      end

      def execute_readonly(sql:, statement_timeout_ms: DEFAULT_STATEMENT_TIMEOUT_MS, max_rows: DEFAULT_ROW_LIMIT)
        DataSources::QuerySafetyGuard.validate!(sql:)
        limited_sql = DataSources::QuerySafetyGuard.limit_sql(sql:, max_rows:)

        with_connection do |connection|
          execute_sql_in_readonly_transaction(
            connection:,
            sql: limited_sql,
            statement_timeout_ms:
          )
        rescue PG::Error
          rollback_transaction(connection)
          raise QueryError.new(I18n.t('app.workspaces.data_sources.query_guard.query_failed'), code: 'query_failed')
        end
      rescue PG::Error
        raise ConnectionError, I18n.t('app.workspaces.data_sources.validation.connection_failed')
      end

      private

      attr_reader :connection_attributes

      def with_connection
        connection = PG.connect(pg_connection_params)
        yield connection
      ensure
        connection&.close
      end

      def pg_connection_params
        attributes = if data_source
                       data_source.connection_config
                     else
                       connection_attributes
                     end

        {
          host: attributes[:host],
          port: attributes[:port],
          dbname: attributes[:database_name],
          user: attributes[:username],
          password: attributes[:password],
          sslmode: attributes[:ssl_mode].presence || DataSource::POSTGRES_DEFAULT_SSL_MODE
        }.compact
      end

      def selected_tables
        if connection_attributes[:selected_tables].present?
          return Array(connection_attributes[:selected_tables]).map(&:to_s).compact_blank
        end

        return data_source.selected_tables if data_source

        []
      end

      def table_list_sql(limit:)
        <<~SQL.squish
          SELECT table_schema, table_name
          FROM information_schema.tables
          WHERE table_type = 'BASE TABLE'
            AND table_schema NOT IN ('pg_catalog', 'information_schema')
          ORDER BY table_schema, table_name
          LIMIT #{limit.to_i}
        SQL
      end

      def build_table_groups(connection:, rows:, include_columns:)
        grouped_rows = rows.group_by { |row| row['table_schema'] }
        columns_lookup = include_columns ? load_columns_lookup(connection:, rows:) : {}

        grouped_rows.map do |schema, schema_rows|
          {
            schema:,
            tables: schema_rows.map do |row|
              qualified_table = qualified_table_name(schema:, table_name: row['table_name'])
              {
                name: row['table_name'],
                qualified_name: qualified_table,
                columns: columns_lookup.fetch(qualified_table, [])
              }
            end
          }
        end
      end

      def load_columns_lookup(connection:, rows:)
        table_pairs = rows.map { |row| [row['table_schema'], row['table_name']] }
        return {} if table_pairs.empty?

        column_result = load_columns_result(connection:, table_pairs:)
        build_columns_lookup(column_result)
      end

      def qualified_table_name(schema:, table_name:)
        "#{schema}.#{table_name}"
      end

      def filter_rows(rows:, selected_only:)
        normalized_rows = rows.to_a
        return normalized_rows unless selected_only && selected_tables.any?

        normalized_rows.select do |row|
          selected_tables.include?(qualified_table_name(schema: row['table_schema'], table_name: row['table_name']))
        end
      end

      def execute_sql_in_readonly_transaction(connection:, sql:, statement_timeout_ms:)
        connection.exec('BEGIN READ ONLY')
        connection.exec("SET LOCAL statement_timeout = '#{statement_timeout_ms}ms'")

        result = connection.exec(sql)
        connection.exec('COMMIT')

        ActiveRecord::Result.new(result.fields, result.values)
      end

      def rollback_transaction(connection)
        connection.exec('ROLLBACK')
      rescue PG::Error
        nil
      end

      def values_sql_for(table_pairs)
        table_pairs.each_with_index.map do |(_, _), index|
          "($#{(index * 2) + 1}, $#{(index * 2) + 2})"
        end.join(', ')
      end

      def load_columns_result(connection:, table_pairs:)
        connection.exec_params(columns_sql(table_pairs), table_pairs.flatten)
      end

      def columns_sql(table_pairs)
        values_sql = values_sql_for(table_pairs)

        <<~SQL.squish
          SELECT table_schema, table_name, column_name, data_type
          FROM information_schema.columns
          WHERE (table_schema, table_name) IN (#{values_sql})
          ORDER BY table_schema, table_name, ordinal_position
        SQL
      end

      def build_columns_lookup(column_result)
        column_result.each_with_object({}) do |row, lookup|
          qualified_table = qualified_table_name(schema: row['table_schema'], table_name: row['table_name'])
          lookup[qualified_table] ||= []
          lookup[qualified_table] << {
            name: row['column_name'],
            data_type: row['data_type']
          }
        end
      end
    end
  end
end
