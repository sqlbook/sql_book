# frozen_string_literal: true

module Tooling
  class UnknownToolError < Error
    attr_reader :tool_name

    def initialize(tool_name:)
      @tool_name = tool_name
      super("Unknown tool: #{tool_name}")
    end
  end
end
