# frozen_string_literal: true

module Chat
  class QueryCardSchemaBuilder
    def initialize(data_source:)
      @data_source = data_source
    end

    def call
      return {} if schema_tables.empty?

      {
        'schema_options' => schema_options,
        'schema_tables' => schema_tables,
        'default_schema_key' => schema_options.first&.last
      }.compact
    end

    private

    attr_reader :data_source

    def schema_options
      schema_tables.map do |table|
        [table['qualified_name'], table['schema_key']]
      end
    end

    def schema_tables
      @schema_tables ||= begin
        tables = data_source.connector.list_tables(include_columns: true, selected_only: data_source.external_database?)
        Array(tables).flat_map do |group|
          normalize_schema_group(group:)
        end
      rescue DataSources::Connectors::BaseConnector::ConnectionError
        []
      end
    end

    def normalize_schema_group(group:)
      schema = group[:schema] || group['schema']
      Array(group[:tables] || group['tables']).map do |table|
        normalize_schema_table(schema:, table:)
      end
    end

    def normalize_schema_table(schema:, table:)
      normalized_table = table.deep_symbolize_keys
      qualified_name = normalized_table[:qualified_name] || [schema, normalized_table[:name]].join('.')

      {
        'name' => normalized_table[:name],
        'qualified_name' => qualified_name,
        'schema_key' => qualified_name.parameterize(separator: '_'),
        'columns' => Array(normalized_table[:columns]).map do |column|
          column.deep_symbolize_keys.slice(:name, :data_type, :default).stringify_keys
        end
      }
    end
  end
end
