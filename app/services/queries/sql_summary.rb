# frozen_string_literal: true

module Queries
  class SqlSummary
    def self.build(sql:)
      new(sql:).call
    end

    def initialize(sql:)
      @sql = Queries::Fingerprint.normalize_sql(sql).to_s
    end

    def call
      {
        table_name: table_name,
        group_by: group_by_columns,
        order_by: order_by_columns,
        limit: limit_value,
        selected_columns: selected_columns,
        aggregate_signature: aggregate_signature
      }
    end

    private

    attr_reader :sql

    def table_name
      sql.match(/\bfrom\s+("?[\w.]+"?)/i)&.captures&.first.to_s.delete('"').presence
    end

    def group_by_columns
      group_by_clause = sql.match(/\bgroup\s+by\s+(.*?)(?:\border\s+by\b|\blimit\b|\z)/im)&.captures&.first.to_s
      split_sql_list(group_by_clause).map { |expression| normalize_identifier(expression) }
    end

    def order_by_columns
      order_by_clause = sql.match(/\border\s+by\s+(.*?)(?:\blimit\b|\z)/im)&.captures&.first.to_s
      split_sql_list(order_by_clause).map { |expression| normalize_order_expression(expression) }
    end

    def limit_value
      sql.match(/\blimit\s+(\d+)\b/i)&.captures&.first.to_i
    end

    def selected_columns
      select_clause = sql.match(/\A\s*select\s+(.*?)\s+from\s+/im)&.captures&.first.to_s
      split_sql_list(select_clause).map { |expression| normalize_identifier(expression) }
    end

    def aggregate_signature
      select_clause = sql.match(/\A\s*select\s+(.*?)\s+from\s+/im)&.captures&.first.to_s
      split_sql_list(select_clause).filter_map do |expression|
        expression.to_s.downcase[/\b(count|sum|avg|min|max)\s*\(/, 1]
      end.sort
    end

    def split_sql_list(clause)
      clause.to_s.split(',').map(&:strip).compact_blank
    end

    def normalize_identifier(expression)
      cleaned = expression.to_s.downcase.strip
      cleaned = cleaned.split(/\s+as\s+/i).last.to_s
      cleaned = cleaned.split('.').last.to_s
      cleaned.delete('"').gsub(/\s+/, ' ').strip
    end

    def normalize_order_expression(expression)
      expression.to_s.downcase.strip.delete('"').gsub(/\s+/, ' ').strip
    end
  end
end
