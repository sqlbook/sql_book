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
      return Result.new(classification: 'material_drift', generated_name:) if ordering_changed?
      return Result.new(classification: 'material_drift', generated_name:) if output_shape_changed?
      return Result.new(classification: 'material_drift', generated_name:) if name_purpose_changed?

      Result.new(classification: 'minor_refinement', generated_name:)
    end

    def source_or_order_changed?
      primary_table_changed? || ordering_changed?
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

    def ordering_changed?
      saved_summary[:order_by] != draft_summary[:order_by]
    end

    def name_purpose_changed?
      return false if generated_name.blank?
      return false if limit_only_refinement?

      normalized_saved_name = normalize_name(saved_query.name)
      normalized_generated_name = normalize_name(generated_name)
      return false unless comparable_names?(normalized_saved_name, normalized_generated_name)

      true
    end

    def saved_summary
      @saved_summary ||= Queries::SqlSummary.build(sql: saved_query.query)
    end

    def draft_summary
      @draft_summary ||= Queries::SqlSummary.build(sql: draft_sql)
    end

    def limit_only_refinement?
      primary_table_unchanged? &&
        grouping_unchanged? &&
        ordering_unchanged? &&
        output_shape_unchanged? &&
        limit_changed?
    end

    def primary_table_unchanged?
      !primary_table_changed?
    end

    def grouping_unchanged?
      !grouping_changed?
    end

    def ordering_unchanged?
      !ordering_changed?
    end

    def output_shape_unchanged?
      !output_shape_changed?
    end

    def limit_changed?
      saved_summary[:limit] != draft_summary[:limit]
    end

    def comparable_names?(normalized_saved_name, normalized_generated_name)
      return false if normalized_saved_name.blank? || normalized_generated_name.blank?
      return false if normalized_saved_name == normalized_generated_name
      return false if normalized_saved_name.include?(normalized_generated_name)
      return false if normalized_generated_name.include?(normalized_saved_name)

      true
    end

    def normalize_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, ' ').squish
    end
  end
end
