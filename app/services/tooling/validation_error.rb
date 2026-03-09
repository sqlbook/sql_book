# frozen_string_literal: true

module Tooling
  class ValidationError < Error
    attr_reader :tool_name, :field, :code

    def initialize(tool_name:, message:, field: nil, code: 'validation_error')
      @tool_name = tool_name
      @field = field
      @code = code
      super(message)
    end
  end
end
