# frozen_string_literal: true

module Tooling
  module WorkspaceDataSourceRegistry
    module_function

    TOOL_CATALOG = [
      {
        name: 'datasource.list',
        description: 'List the data sources connected to the current workspace. This is read only.',
        input_schema: {
          'type' => 'object',
          'properties' => {}
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'read',
        confirmation_mode: 'none',
        handler_method: :list
      },
      {
        name: 'datasource.validate_connection',
        description: [
          'Validate a PostgreSQL connection',
          'and return the discovered tables for the current workspace flow.'
        ].join(' '),
        input_schema: {
          'type' => 'object',
          'required' => %w[host database_name username password],
          'properties' => {
            'host' => { 'type' => 'string', 'min_length' => 1 },
            'port' => { 'type' => 'integer' },
            'database_name' => { 'type' => 'string', 'min_length' => 1 },
            'username' => { 'type' => 'string', 'min_length' => 1 },
            'password' => { 'type' => 'string', 'min_length' => 1 },
            'ssl_mode' => { 'type' => 'string' },
            'extract_category_values' => { 'type' => 'boolean' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler_method: :validate_connection
      },
      {
        name: 'datasource.create',
        description: [
          'Create a PostgreSQL data source in the current workspace',
          'using the validated connection details and selected tables.'
        ].join(' '),
        input_schema: {
          'type' => 'object',
          'required' => %w[name host database_name username password selected_tables],
          'properties' => {
            'name' => { 'type' => 'string', 'min_length' => 1 },
            'host' => { 'type' => 'string', 'min_length' => 1 },
            'port' => { 'type' => 'integer' },
            'database_name' => { 'type' => 'string', 'min_length' => 1 },
            'username' => { 'type' => 'string', 'min_length' => 1 },
            'password' => { 'type' => 'string', 'min_length' => 1 },
            'ssl_mode' => { 'type' => 'string' },
            'extract_category_values' => { 'type' => 'boolean' },
            'selected_tables' => {
              'type' => 'array',
              'items' => { 'type' => 'string', 'min_length' => 1 }
            }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler_method: :create
      }
    ].freeze

    def tool_metadata
      TOOL_CATALOG.map { |tool| tool.except(:handler_method) }
    end

    def definitions(handlers:)
      TOOL_CATALOG.map do |tool|
        Registry::ToolDefinition.new(
          name: tool[:name],
          description: tool[:description],
          input_schema: tool[:input_schema],
          output_schema: tool[:output_schema],
          risk_level: tool[:risk_level],
          confirmation_mode: tool[:confirmation_mode],
          handler: ->(arguments:) { handlers.public_send(tool[:handler_method], arguments:) }
        )
      end
    end
  end
end
