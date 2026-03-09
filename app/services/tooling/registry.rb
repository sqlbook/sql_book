# frozen_string_literal: true

require 'uri'

module Tooling
  class Registry # rubocop:disable Metrics/ClassLength
    ToolDefinition = Struct.new(
      :name,
      :description,
      :input_schema,
      :output_schema,
      :risk_level,
      :confirmation_mode,
      :handler,
      keyword_init: true
    )

    SUPPORTED_TYPES = %w[string integer number boolean object array].freeze
    TYPE_VALIDATORS = {
      'string' => ->(value) { value.is_a?(String) },
      'integer' => ->(value) { value.is_a?(Integer) },
      'number' => ->(value) { value.is_a?(Numeric) },
      'boolean' => ->(value) { [true, false].include?(value) },
      'object' => ->(value) { value.is_a?(Hash) },
      'array' => ->(value) { value.is_a?(Array) }
    }.freeze

    def initialize(definitions:)
      @definitions = Array(definitions).index_by(&:name)
    end

    def definitions
      @definitions.values
    end

    def definition(name)
      @definitions[name.to_s]
    end

    def execute(name:, arguments:)
      tool = definition(name)
      raise UnknownToolError.new(tool_name: name) if tool.nil?

      validated_arguments = validate_arguments!(tool:, arguments: arguments.to_h)
      tool.handler.call(arguments: validated_arguments)
    end

    private

    def validate_arguments!(tool:, arguments:)
      schema = tool.input_schema.to_h
      return arguments if schema.empty?

      validate_object_type!(tool:, arguments:)
      validate_required_fields!(tool:, schema:, arguments:)
      validate_properties!(tool:, schema:, arguments:)
      arguments
    end

    def validate_object_type!(tool:, arguments:)
      return if arguments.is_a?(Hash)

      raise ValidationError.new(
        tool_name: tool.name,
        message: "#{tool.name}: expected object arguments",
        code: 'invalid_arguments'
      )
    end

    def validate_required_fields!(tool:, schema:, arguments:)
      Array(schema['required']).each do |field|
        next unless arguments[field].nil? || arguments[field].to_s.strip.blank?

        raise ValidationError.new(
          tool_name: tool.name,
          field: field,
          message: "#{tool.name}: missing required field `#{field}`",
          code: 'missing_required_argument'
        )
      end
    end

    def validate_properties!(tool:, schema:, arguments:)
      properties = schema['properties'].to_h
      arguments.each do |field, value|
        validate_property!(tool:, properties:, field:, value:)
      end
    end

    def validate_type!(tool:, field:, value:, expected_type:)
      valid = TYPE_VALIDATORS.fetch(expected_type).call(value)

      return if valid

      raise ValidationError.new(
        tool_name: tool.name,
        field: field,
        message: "#{tool.name}: field `#{field}` must be #{expected_type}",
        code: 'invalid_argument_type'
      )
    end

    def validate_min_length!(tool:, field:, value:, property:)
      min_length = property['min_length']
      return if min_length.blank?
      return unless value.is_a?(String)
      return if value.strip.length >= min_length.to_i

      raise ValidationError.new(
        tool_name: tool.name,
        field: field,
        message: "#{tool.name}: field `#{field}` is too short",
        code: 'invalid_argument'
      )
    end

    def validate_enum!(tool:, field:, value:, property:)
      enum_values = Array(property['enum'])
      return if enum_values.empty? || enum_values.include?(value)

      raise ValidationError.new(
        tool_name: tool.name,
        field: field,
        message: "#{tool.name}: field `#{field}` is not an allowed value",
        code: 'invalid_argument'
      )
    end

    def validate_email_format!(tool:, field:, value:, property:)
      return unless property['format'].to_s == 'email'
      return unless value.is_a?(String)
      return if value.match?(URI::MailTo::EMAIL_REGEXP)

      raise ValidationError.new(
        tool_name: tool.name,
        field: field,
        message: "#{tool.name}: field `#{field}` must be a valid email",
        code: 'invalid_argument'
      )
    end

    def validate_property!(tool:, properties:, field:, value:)
      property = properties[field].to_h
      return if property.empty?

      expected_type = property['type'].to_s
      validate_schema_type!(tool:, field:, expected_type:)
      validate_type!(tool:, field:, value:, expected_type:) if expected_type.present?
      validate_min_length!(tool:, field:, value:, property:)
      validate_enum!(tool:, field:, value:, property:)
      validate_email_format!(tool:, field:, value:, property:)
    end

    def validate_schema_type!(tool:, field:, expected_type:)
      return if expected_type.blank? || SUPPORTED_TYPES.include?(expected_type)

      raise ValidationError.new(
        tool_name: tool.name,
        field: field,
        message: "#{tool.name}: unsupported schema type `#{expected_type}` for `#{field}`",
        code: 'invalid_schema'
      )
    end
  end
end
