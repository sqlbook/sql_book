# frozen_string_literal: true

module Queries
  class SchemaContextBuilder
    MAX_TABLES = 12
    MAX_COLUMNS = 8

    def self.call(data_source:)
      new(data_source:).call
    end

    def initialize(data_source:)
      @data_source = data_source
    end

    def call
      Array(listed_tables).flat_map do |group|
        Array(value_from(group, :tables)).map do |table|
          build_table_entry(schema: value_from(group, :schema), table:)
        end
      end.compact.first(MAX_TABLES)
    rescue DataSources::Connectors::BaseConnector::ConnectionError
      []
    end

    private

    attr_reader :data_source

    def listed_tables
      data_source.connector.list_tables(
        include_columns: true,
        selected_only: data_source.external_database?
      )
    end

    def build_table_entry(schema:, table:)
      table_name = value_from(table, :qualified_name) || [schema, value_from(table, :name)].compact.join('.')
      return if table_name.blank?

      columns = Array(value_from(table, :columns)).filter_map do |column|
        value_from(column, :name)
      end.first(MAX_COLUMNS)
      return table_name if columns.empty?

      "#{table_name}: #{columns.join(', ')}"
    end

    def value_from(object, key)
      object[key] || object[key.to_s]
    end
  end
end
