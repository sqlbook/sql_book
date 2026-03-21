# frozen_string_literal: true

module Queries
  module NameGenerator
    module_function

    def generate(question:, sql:, data_source:)
      sql_name = descriptive_name_from_sql(sql:)
      return sql_name if sql_name.present?

      cleaned_question = normalized_question(question)
      return cleaned_question if cleaned_question.present?

      "#{data_source.display_name} query"
    end

    def normalized_question(question)
      value = question.to_s.strip
      return nil if value.blank?
      return nil if value.match?(/\A\s*(select|with)\b/i)
      return nil if generic_analytic_question?(value)
      return nil if conversational_request?(value)

      value.gsub(/\s+/, ' ').sub(/[.!?]+\z/, '').truncate(80)
    end

    def generic_analytic_question?(value)
      value.match?(/\A\s*(how many|count|total|show me how many|show me|list|find|get)\b/i)
    end

    def conversational_request?(value)
      normalized = value.gsub(/\s+/, ' ').strip
      return true if normalized.length > 55

      normalized.match?(/\A(?:can|could|would|will|please|show|tell|give|help|run|query|get|find|list)\b/i)
    end

    def descriptive_name_from_sql(sql:)
      table_name = table_name_from(sql:)
      return nil if table_name.blank?

      selected_columns = selected_columns_from(sql:)
      return count_name_for(table_name:) if count_query?(selected_columns)

      column_name = column_driven_name_for(table_name:, columns: selected_columns)
      return column_name if column_name.present?

      "#{human_table_name(table_name)} query"
    end

    def table_name_from(sql:)
      match = sql.to_s.match(/\bfrom\s+("?[\w.]+"?)/i)
      return nil unless match

      match[1].to_s.delete('"').presence
    end

    def selected_columns_from(sql:)
      match = sql.to_s.match(/\A\s*select\s+(.*?)\s+from\s+/im)
      return [] unless match

      match[1]
        .split(',')
        .map { |column| column.to_s.strip.downcase }
        .compact_blank
    end

    def count_query?(columns)
      columns.any? { |column| column.include?('count(') || column.include?('count(*)') }
    end

    def count_name_for(table_name:)
      "#{human_table_name(table_name).singularize} count"
    end

    def column_driven_name_for(table_name:, columns:)
      return nil if columns.empty?

      normalized_columns = columns.map { |column| column.split(/\s+as\s+/i).last.to_s.strip }

      if user_name_and_email_columns?(normalized_columns)
        return "#{human_table_name(table_name).singularize} names and email addresses"
      end

      return human_table_name(table_name) if normalized_columns == ['*']

      nil
    end

    def user_name_and_email_columns?(columns)
      columns.include?('email') &&
        columns.include?('first_name') &&
        columns.include?('last_name')
    end

    def human_table_name(table_name)
      table_name.to_s.split('.').last.to_s.tr('_', ' ').titleize
    end
  end
end
