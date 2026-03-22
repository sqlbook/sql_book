# frozen_string_literal: true

module Queries
  # rubocop:disable Metrics/ModuleLength
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

    def descriptive_name_from_sql(sql:) # rubocop:disable Metrics/MethodLength
      table_name = table_name_from(sql:)
      return nil if table_name.blank?

      selected_columns = selected_columns_from(sql:)
      ilike_filter = ilike_filter_details_from(sql:)
      if count_query?(selected_columns)
        filtered_name = filtered_count_name_for(table_name:, ilike_filter:)
        return filtered_name if filtered_name.present?

        grouped_name = grouped_count_name_for(table_name:, sql:)
        return grouped_name if grouped_name.present?

        return count_name_for(table_name:)
      end

      column_name = column_driven_name_for(table_name:, columns: selected_columns, ilike_filter:)
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

    def filtered_count_name_for(table_name:, ilike_filter:)
      return nil if ilike_filter.blank?

      [
        count_name_for(table_name:),
        "with '#{ilike_filter[:fragment]}' in #{human_filter_column(ilike_filter[:column_name])}"
      ].join(' ')
    end

    def grouped_count_name_for(table_name:, sql:)
      group_columns = group_by_columns_from(sql:)
      return nil if group_columns.empty?

      "#{count_name_for(table_name:)} by #{human_group_columns(group_columns)}"
    end

    def column_driven_name_for(table_name:, columns:, ilike_filter:)
      return nil if columns.empty?

      normalized_columns = columns.map { |column| column.split(/\s+as\s+/i).last.to_s.strip }

      user_list_name = filtered_user_list_name_for(table_name:, ilike_filter:, normalized_columns:)
      return user_list_name if user_list_name.present?

      return human_table_name(table_name) if normalized_columns == ['*']

      nil
    end

    def user_name_and_email_columns?(columns)
      columns.include?('email') &&
        columns.include?('first_name') &&
        columns.include?('last_name')
    end

    def filtered_user_list_name_for(table_name:, ilike_filter:, normalized_columns:)
      return nil unless user_name_and_email_columns?(normalized_columns)

      if ilike_filter.present?
        return [
          human_table_name(table_name),
          "with '#{ilike_filter[:fragment]}' in #{human_filter_column(ilike_filter[:column_name])}"
        ].join(' ')
      end

      "#{human_table_name(table_name).singularize} names and email addresses"
    end

    def group_by_columns_from(sql:)
      group_by_clause = sql.to_s.match(/\bgroup\s+by\s+(.*?)(?:\border\s+by\b|\blimit\b|\z)/im)&.captures&.first.to_s
      group_by_clause
        .split(',')
        .map { |column| column.to_s.strip.split('.').last.to_s.delete('"') }
        .compact_blank
    end

    def human_group_columns(columns)
      columns.map { |column| human_group_column(column) }.join(' and ')
    end

    def human_group_column(column)
      humanized = column.to_s.tr('_', ' ').strip
      return "#{humanized} status" if humanized.end_with?('admin')

      humanized
    end

    def human_filter_column(column)
      human_group_column(column).sub(/\s+status\z/, '')
    end

    def ilike_filter_details_from(sql:)
      ilike_match = sql.to_s.match(/\bwhere\s+("?[\w.]+"?)\s+ilike\s+'%([^']+)%'/i)
      return nil unless ilike_match

      column_name = ilike_match[1].to_s.delete('"').split('.').last
      fragment = ilike_match[2].to_s
      return nil if column_name.blank? || fragment.blank?

      {
        column_name:,
        fragment:
      }
    end

    def human_table_name(table_name)
      table_name.to_s.split('.').last.to_s.tr('_', ' ').titleize
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
