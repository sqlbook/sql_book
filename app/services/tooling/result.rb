# frozen_string_literal: true

module Tooling
  class Result
    DEFAULT_CODES = {
      'executed' => 'tool.executed',
      'validation_error' => 'tool.validation_error',
      'execution_error' => 'tool.execution_error',
      'forbidden' => 'tool.forbidden'
    }.freeze

    attr_reader :status, :code, :data, :fallback_message

    def initialize(status:, code: nil, data: {}, fallback_message: nil, **legacy)
      @status = status
      @code = normalized_code(code: code, error_code: legacy[:error_code], status: status)
      @data = data || {}
      @fallback_message = normalized_fallback_message(
        fallback_message:,
        message: legacy[:message]
      )
    end

    def message
      fallback_message
    end

    def error_code
      legacy_error_code
    end

    private

    def legacy_error_code
      return code unless code.to_s.include?('.')

      _namespace, remainder = code.to_s.split('.', 2)
      remainder.to_s.tr('.', '_')
    end

    def normalized_code(code:, error_code:, status:)
      value = code.presence || error_code.presence
      value.presence || DEFAULT_CODES[status.to_s] || 'tool.unknown'
    end

    def normalized_fallback_message(fallback_message:, message:)
      value = fallback_message.presence || message.presence
      value.to_s.strip.presence
    end
  end
end
