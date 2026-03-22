# frozen_string_literal: true

module Queries
  class DriftClassifier
    Result = Struct.new(:classification, :generated_name, keyword_init: true) do
      def exact_duplicate?
        classification == 'exact_duplicate'
      end

      def minor_refinement?
        classification == 'minor_refinement'
      end

      def material_drift?
        classification == 'material_drift'
      end
    end

    def initialize(saved_query:, draft_sql:, generated_name: nil)
      @saved_query = saved_query
      @draft_sql = draft_sql.to_s
      @generated_name = generated_name.to_s.presence
    end

    def call # rubocop:disable Metrics/AbcSize
      return Result.new(classification: 'exact_duplicate', generated_name:) if exact_duplicate?
      return Result.new(classification: 'material_drift', generated_name:) if primary_table_changed?
      return Result.new(classification: 'material_drift', generated_name:) if grouping_changed?
      return Result.new(classification: 'material_drift', generated_name:) if output_shape_changed?
      return Result.new(classification: 'material_drift', generated_name:) if name_purpose_changed?

      Result.new(classification: 'minor_refinement', generated_name:)
    end

    private

    attr_reader :saved_query, :draft_sql, :generated_name

    def exact_duplicate?
      Queries::Fingerprint.build(data_source_id: saved_query.data_source_id, sql: saved_query.query) ==
        Queries::Fingerprint.build(data_source_id: saved_query.data_source_id, sql: draft_sql)
    end

    def primary_table_changed?
      saved_summary[:table_name] != draft_summary[:table_name]
    end

    def grouping_changed?
      saved_summary[:group_by] != draft_summary[:group_by]
    end

    def output_shape_changed?
      saved_summary[:aggregate_signature] != draft_summary[:aggregate_signature] ||
        saved_summary[:selected_columns] != draft_summary[:selected_columns]
    end

    def name_purpose_changed?
      return false if generated_name.blank?

      normalized_saved_name = normalize_name(saved_query.name)
      normalized_generated_name = normalize_name(generated_name)
      return false if normalized_saved_name.blank? || normalized_generated_name.blank?
      return false if normalized_saved_name == normalized_generated_name
      return false if normalized_saved_name.include?(normalized_generated_name)
      return false if normalized_generated_name.include?(normalized_saved_name)

      true
    end

    def saved_summary
      @saved_summary ||= summarize(sql: saved_query.query)
    end

    def draft_summary
      @draft_summary ||= summarize(sql: draft_sql)
    end

    def summarize(sql:)
      normalized_sql = Queries::Fingerprint.normalize_sql(sql).to_s
      {
        table_name: table_name_from(sql: normalized_sql),
        group_by: group_by_columns_from(sql: normalized_sql),
        selected_columns: selected_columns_from(sql: normalized_sql),
        aggregate_signature: aggregate_signature_from(sql: normalized_sql)
      }
    end

    def table_name_from(sql:)
      sql.match(/\bfrom\s+("?[\w.]+"?)/i)&.captures&.first.to_s.delete('"').presence
    end

    def group_by_columns_from(sql:)
      group_by_clause = sql.match(/\bgroup\s+by\s+(.*?)(?:\border\s+by\b|\blimit\b|\z)/im)&.captures&.first.to_s
      split_sql_list(group_by_clause).map { |expression| normalize_identifier(expression) }
    end

    def selected_columns_from(sql:)
      select_clause = sql.match(/\A\s*select\s+(.*?)\s+from\s+/im)&.captures&.first.to_s
      split_sql_list(select_clause).map { |expression| normalize_identifier(expression) }
    end

    def aggregate_signature_from(sql:)
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

    def normalize_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, ' ').squish
    end
  end
end
