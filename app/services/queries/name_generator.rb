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

    def generate_alternative(question:, sql:, data_source:, existing_names:)
      existing_name_set = normalized_existing_name_set(existing_names)
      resolved_candidate = first_available_candidate(
        candidates: alternative_name_candidates(question:, sql:, data_source:),
        existing_name_set:
      )
      return resolved_candidate if resolved_candidate.present?

      fallback_base = generate(question:, sql:, data_source:)
      fallback_candidate_for(base: fallback_base, existing_name_set:)
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

    def alternative_name_candidates(question:, sql:, data_source:)
      table_name = table_name_from(sql:)
      selected_columns = selected_columns_from(sql:)
      ilike_filter = ilike_filter_details_from(sql:)
      group_columns = group_by_columns_from(sql:)

      [
        alternative_name_from_sql(
          table_name:,
          selected_columns:,
          ilike_filter:,
          group_columns:
        ),
        descriptive_name_from_sql(sql:),
        normalized_question(question),
        "#{human_table_name(table_name)} overview".presence,
        "#{data_source.display_name} query"
      ].compact_blank.uniq
    end

    def alternative_name_from_sql(table_name:, selected_columns:, ilike_filter:, group_columns:)
      return nil if table_name.blank?

      return alternative_count_name_for(table_name:, ilike_filter:, group_columns:) if count_query?(selected_columns)

      normalized_columns = selected_columns.map { |column| column.split(/\s+as\s+/i).last.to_s.strip }
      alternative_column_name_for(table_name:, normalized_columns:, ilike_filter:)
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

    def alternative_count_name_for(table_name:, ilike_filter:, group_columns:)
      prefix = "Total #{human_table_name(table_name).downcase}"
      if ilike_filter.present?
        return "#{prefix} with '#{ilike_filter[:fragment]}' in #{human_filter_column(ilike_filter[:column_name])}"
      end

      return "#{human_table_name(table_name)} grouped by #{human_group_columns(group_columns)}" if group_columns.any?

      prefix
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

    def alternative_column_name_for(table_name:, normalized_columns:, ilike_filter:)
      if user_name_and_email_columns?(normalized_columns)
        return users_name_and_email_alternative_for(table_name:, ilike_filter:)
      end

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

    def users_name_and_email_alternative_for(table_name:, ilike_filter:)
      base = "#{human_table_name(table_name)}: names and emails"
      if ilike_filter.present?
        return "#{base} with '#{ilike_filter[:fragment]}' in #{human_filter_column(ilike_filter[:column_name])}"
      end

      base
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

    def normalized_existing_name_set(existing_names)
      Array(existing_names).filter_map { |name| name.to_s.strip.downcase.presence }.to_set
    end

    def first_available_candidate(candidates:, existing_name_set:)
      Array(candidates).each do |candidate|
        cleaned_candidate = candidate.to_s.strip.presence
        next if cleaned_candidate.blank?
        next if existing_name_set.include?(cleaned_candidate.downcase)

        return cleaned_candidate
      end

      nil
    end

    def fallback_candidate_for(base:, existing_name_set:)
      candidate = "#{base} query".strip
      return candidate unless existing_name_set.include?(candidate.downcase)

      suffix = 2
      loop do
        numbered_candidate = "#{base} #{suffix}"
        return numbered_candidate unless existing_name_set.include?(numbered_candidate.downcase)

        suffix += 1
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
