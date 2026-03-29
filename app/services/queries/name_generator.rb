# frozen_string_literal: true

module Queries
  module NameGenerator
    module_function

    def generate(question:, sql:, data_source:)
      descriptive_name_from_question(question).presence ||
        descriptive_name_from_sql(sql:).presence ||
        "#{data_source.display_name} query"
    end

    def descriptive_name_from_question(question)
      value = question.to_s.strip
      return nil if value.blank?
      return nil if value.match?(/\A\s*(select|with)\b/i)
      return nil if generic_analytic_question?(value)
      return nil if refinement_request?(value)

      cleaned_question(value).presence&.truncate(80)
    end

    def descriptive_name_from_sql(sql:)
      table_name = table_name_from(sql:)
      return nil if table_name.blank?

      return "#{human_table_name(table_name).singularize} count" if count_query?(sql:)

      "#{human_table_name(table_name)} query"
    end

    def count_query?(sql:)
      sql.to_s.match?(/\bcount\s*\(/i)
    end

    def generic_analytic_question?(value)
      value.match?(/\A\s*(how many|count|total|show me how many|show me|list|find|get)\b/i)
    end

    def refinement_request?(value)
      value.match?(/\A\s*(adjust|refine|update|change)\b/i)
    end

    def cleaned_question(value)
      value
        .gsub(/\s+/, ' ')
        .sub(/[.!?]+\z/, '')
        .sub(/\A(?:can you|could you|would you|will you|please)\s+/i, '')
        .sub(/\A(?:show me|list|find|get|tell me|give me)\s+/i, '')
        .sub(/\A(?:who are|what are|which are)\s+/i, '')
        .sub(/\Athe\s+/i, '')
        .sub(/\s+(?:in|from)\s+(?:my\s+)?[\w\s-]+(?:db|database|datasource|data source)\z/i, '')
        .strip
    end

    def table_name_from(sql:)
      match = sql.to_s.match(/\bfrom\s+("?[\w.]+"?)/i)
      return nil unless match

      match[1].to_s.delete('"').presence
    end

    def human_table_name(table_name)
      table_name.to_s.split('.').last.to_s.tr('_', ' ').titleize
    end
  end
end
