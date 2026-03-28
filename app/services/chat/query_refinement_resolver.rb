# frozen_string_literal: true

module Chat
  class QueryRefinementResolver
    Result = Struct.new(
      :draft_reference,
      :target_query,
      :classification,
      :generated_name,
      keyword_init: true
    ) do
      # rubocop:disable Rails/Delegate
      def present?
        draft_reference.present?
      end
      # rubocop:enable Rails/Delegate

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

    def initialize(workspace:, context_snapshot:)
      @workspace = workspace
      @context_snapshot = context_snapshot
    end

    def resolve
      draft_reference = context_snapshot&.recent_draft_query_reference.to_h.deep_stringify_keys
      if draft_reference.blank?
        return Result.new(
          draft_reference: {},
          target_query: nil,
          classification: nil,
          generated_name: nil
        )
      end

      target_query = target_query_for(draft_reference:)
      generated_name = generated_name_for(draft_reference:)
      classification = classify(target_query:, draft_reference:, generated_name:)

      Result.new(
        draft_reference:,
        target_query:,
        classification:,
        generated_name:
      )
    end

    private

    attr_reader :workspace, :context_snapshot

    def target_query_for(draft_reference:)
      explicit_target_id = draft_reference['refined_saved_query_id'].presence ||
                           draft_reference['saved_query_id'].presence
      return nil if explicit_target_id.blank?

      query_by_id(explicit_target_id)
    end

    def query_by_id(query_id)
      return nil if query_id.to_s.strip.blank?

      Queries::LibraryService.new(workspace:).call.find { |query| query.id == query_id.to_i }
    end

    def generated_name_for(draft_reference:)
      data_source = workspace.data_sources.find_by(id: draft_reference['data_source_id'])
      return nil unless data_source

      Queries::NameGenerator.generate(
        question: draft_reference['original_question'],
        sql: draft_reference['sql'],
        data_source:
      )
    end

    def classify(target_query:, draft_reference:, generated_name:)
      return nil unless target_query

      Queries::DriftClassifier.new(
        saved_query: target_query,
        draft_sql: draft_reference['sql'],
        generated_name:
      ).call.classification
    end
  end
end
