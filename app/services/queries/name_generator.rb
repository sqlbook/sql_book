# frozen_string_literal: true

module Queries
  module NameGenerator
    module_function

    def generate(question:, sql:, data_source:)
      cleaned_question = normalized_question(question)
      return cleaned_question if cleaned_question.present?

      table_name = table_name_from(sql:)
      return "Query on #{table_name}" if table_name.present?

      "#{data_source.display_name} query"
    end

    def normalized_question(question)
      value = question.to_s.strip
      return nil if value.blank?
      return nil if value.match?(/\A\s*(select|with)\b/i)

      value.gsub(/\s+/, ' ').sub(/[.!?]+\z/, '').truncate(80)
    end

    def table_name_from(sql:)
      match = sql.to_s.match(/\bfrom\s+("?[\w.]+"?)/i)
      return nil unless match

      match[1].to_s.delete('"').presence
    end
  end
end
