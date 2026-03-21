# frozen_string_literal: true

module Tooling
  module WorkspaceQueryRegistry
    module_function

    TOOL_CATALOG = [
      {
        name: 'query.list',
        description: 'List saved queries in the current workspace query library.',
        input_schema: {
          'type' => 'object',
          'properties' => {
            'search' => { 'type' => 'string', 'min_length' => 1 },
            'data_source_id' => { 'type' => 'integer' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'read',
        confirmation_mode: 'none',
        handler_method: :list
      },
      {
        name: 'query.run',
        description: 'Run a read-only query against a connected data source in the current workspace.',
        input_schema: {
          'type' => 'object',
          'required' => %w[question],
          'properties' => {
            'question' => { 'type' => 'string', 'min_length' => 1 },
            'data_source_id' => { 'type' => 'integer' },
            'data_source_name' => { 'type' => 'string', 'min_length' => 1 }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'read',
        confirmation_mode: 'none',
        handler_method: :run
      },
      {
        name: 'query.save',
        description: 'Save a query to the current workspace query library.',
        input_schema: {
          'type' => 'object',
          'properties' => {
            'name' => { 'type' => 'string', 'min_length' => 1 },
            'sql' => { 'type' => 'string', 'min_length' => 1 },
            'question' => { 'type' => 'string', 'min_length' => 1 },
            'data_source_id' => { 'type' => 'integer' },
            'data_source_name' => { 'type' => 'string', 'min_length' => 1 }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'write',
        confirmation_mode: 'none',
        handler_method: :save
      },
      {
        name: 'query.rename',
        description: 'Rename a saved query in the current workspace query library.',
        input_schema: {
          'type' => 'object',
          'required' => %w[query_id name],
          'properties' => {
            'query_id' => { 'type' => 'integer' },
            'name' => { 'type' => 'string', 'min_length' => 1 }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'write',
        confirmation_mode: 'none',
        handler_method: :rename
      },
      {
        name: 'query.delete',
        description: 'Delete a saved query from the current workspace query library.',
        input_schema: {
          'type' => 'object',
          'required' => %w[query_id],
          'properties' => {
            'query_id' => { 'type' => 'integer' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'write',
        confirmation_mode: 'required',
        handler_method: :delete
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
