# frozen_string_literal: true

module Tooling
  module WorkspaceChatThreadRegistry
    module_function

    TOOL_CATALOG = [
      {
        name: 'thread.rename',
        description: 'Rename the current private chat thread for the current workspace member.',
        input_schema: {
          'type' => 'object',
          'required' => %w[thread_id title],
          'properties' => {
            'thread_id' => { 'type' => 'integer' },
            'title' => { 'type' => 'string', 'min_length' => 1 }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'write',
        confirmation_mode: 'none',
        handler_method: :rename
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
