# frozen_string_literal: true

module Chat
  class QueryReferenceStore # rubocop:disable Metrics/ClassLength
    LOAD_LIMIT = 8

    def initialize(chat_thread:, workspace:, actor: nil)
      @chat_thread = chat_thread
      @workspace = workspace
      @actor = actor
    end

    def load(limit: LOAD_LIMIT)
      ensure_seeded_from_legacy_state!
      references.limit(limit).map(&:serialized_payload)
    end

    def recent_reference
      load(limit: 1).first.to_h
    end

    def recent_saved_reference
      ensure_seeded_from_legacy_state!
      reference = references.where.not(saved_query_id: nil).first
      reference ? reference.serialized_payload : {}
    end

    def recent_saved_reference_record
      ensure_seeded_from_legacy_state!
      references.where.not(saved_query_id: nil).first
    end

    # rubocop:disable Metrics/AbcSize
    def record_query_run!(source_message:, result_message:, execution:, fallback_question: nil)
      data = execution.data.to_h.deep_stringify_keys
      return if ActiveModel::Type::Boolean.new.cast(data['clarification_required'])

      data_source = data_source_for(id: data.dig('data_source', 'id'))
      refined_from_reference = refinement_base_reference_for(question: data['question'].presence || fallback_question)
      chat_thread.chat_query_references.create!(
        source_message:,
        result_message:,
        refined_from_reference:,
        data_source:,
        original_question: data['question'].presence || fallback_question.to_s.strip.presence,
        sql: data['sql'].to_s.presence,
        current_name: current_name_for(
          question: data['question'].presence || fallback_question,
          sql: data['sql'],
          data_source:
        ),
        row_count: integer_value(data['row_count']),
        columns: Array(data['columns'])
      )
    end
    # rubocop:enable Metrics/AbcSize

    def record_query_save!(source_message:, result_message:, execution:, fallback_question: nil)
      data = execution.data.to_h.deep_stringify_keys
      query = saved_query_from(data:)
      return unless query

      reference = reference_for_saved_query(query) ||
                  matching_unsaved_reference_for(query:) ||
                  build_saved_query_reference(
                    query:,
                    source_message:,
                    result_message:,
                    original_question: fallback_question
                  )

      reference.attach_saved_query!(query:, source_message:, result_message:)
      reference
    end

    def record_query_rename!(result_message:, execution:)
      data = execution.data.to_h.deep_stringify_keys
      query = saved_query_from(data:)
      return unless query

      reference = reference_for_saved_query(query) || build_saved_query_reference(query:, result_message:)
      reference.rename_to!(new_name: query.name, result_message:)
      reference
    end

    def record_query_update!(source_message:, result_message:, execution:, fallback_question: nil)
      data = execution.data.to_h.deep_stringify_keys
      query = saved_query_from(data:)
      return unless query

      reference = reference_for_saved_query(query) ||
                  matching_unsaved_reference_for(query:) ||
                  build_saved_query_reference(
                    query:,
                    source_message:,
                    result_message:,
                    original_question: fallback_question
                  )

      reference.source_message ||= source_message
      reference.result_message ||= result_message
      reference.sync_with_saved_query!(query:)
      reference
    end

    def record_query_delete!(result_message:, execution:)
      deleted_query = execution.data.to_h.deep_stringify_keys['deleted_query'].to_h.deep_stringify_keys
      return if deleted_query.blank?

      reference = reference_for_deleted_query(deleted_query:)
      reference ||= build_deleted_query_reference(deleted_query:, result_message:)
      reference.unlink_saved_query!(fallback_name: deleted_query['name'], result_message:)
      reference
    end

    def sync_saved_query!(query:)
      reference = reference_for_saved_query(query)
      return unless reference

      reference.rename_to!(new_name: query.name)
      reference
    end

    private

    attr_reader :chat_thread, :workspace, :actor

    def references
      chat_thread.chat_query_references.recent_first
    end

    # rubocop:disable Metrics/AbcSize
    def ensure_seeded_from_legacy_state!
      return if defined?(@legacy_seeded)

      @legacy_seeded = true
      return if chat_thread.chat_query_references.exists?

      state = legacy_recent_query_state
      return if state.blank? || state['sql'].to_s.strip.blank?

      chat_thread.chat_query_references.create!(
        data_source: data_source_for(id: state['data_source_id']),
        original_question: state['question'].to_s.presence,
        sql: state['sql'].to_s.presence,
        current_name: state['saved_query_name'].to_s.presence ||
                      current_name_for(
                        question: state['question'],
                        sql: state['sql'],
                        data_source: data_source_for(id: state['data_source_id'])
                      ),
        row_count: integer_value(state['row_count']),
        columns: Array(state['columns']),
        saved_query: saved_query_for(id: state['saved_query_id'])
      )
    end
    # rubocop:enable Metrics/AbcSize

    def legacy_recent_query_state
      return {} unless chat_thread.has_attribute?(:metadata)

      chat_thread.reload.metadata.to_h.deep_stringify_keys['recent_query_state'].to_h.deep_stringify_keys
    end

    def matching_unsaved_reference_for(query:)
      references
        .where(saved_query_id: nil, data_source_id: query.data_source_id)
        .where(sql: query.query)
        .first
    end

    def build_saved_query_reference(query:, source_message: nil, result_message: nil, original_question: nil)
      chat_thread.chat_query_references.create!(
        source_message:,
        result_message:,
        data_source: query.data_source,
        saved_query: query,
        original_question: original_question.to_s.presence,
        sql: query.query,
        current_name: query.name
      )
    end

    def refinement_base_reference_for(question:)
      return unless refinement_follow_up?(question)

      recent_saved_reference_record
    end

    def refinement_follow_up?(question)
      question.to_s.match?(
        /\b(adjust|update|change|modify|refine|instead|also|split|group|break(?:\s+it)?\s+down|filter|show)\b/i
      )
    end

    def build_deleted_query_reference(deleted_query:, result_message:)
      chat_thread.chat_query_references.create!(
        result_message:,
        data_source: data_source_for(id: deleted_query.dig('data_source', 'id')),
        sql: deleted_query['sql'].to_s.presence,
        current_name: deleted_query['name'].to_s.presence,
        row_count: integer_value(deleted_query['row_count']),
        columns: Array(deleted_query['columns'])
      )
    end

    # rubocop:disable Metrics/AbcSize
    def reference_for_deleted_query(deleted_query:)
      references.find_by(saved_query_id: integer_value(deleted_query['id'])) ||
        references.find_by(
          current_name: deleted_query['name'].to_s.presence,
          sql: deleted_query['sql'].to_s.presence
        ) ||
        references.where(
          current_name: deleted_query['name'].to_s.presence,
          data_source_id: integer_value(deleted_query.dig('data_source', 'id'))
        ).first
    end
    # rubocop:enable Metrics/AbcSize

    def saved_query_from(data:)
      query_payload = data['query'].to_h.deep_stringify_keys
      return if query_payload.blank?

      saved_query_for(id: query_payload['id'])
    end

    def saved_query_for(id:)
      query_id = integer_value(id)
      return if query_id.blank?

      Query.find_by(id: query_id)
    end

    def reference_for_saved_query(query)
      return unless query

      references.find_by(saved_query_id: query.id)
    end

    def data_source_for(id:)
      data_source_id = integer_value(id)
      return if data_source_id.blank?

      workspace.data_sources.find_by(id: data_source_id)
    end

    def current_name_for(question:, sql:, data_source:)
      return if sql.to_s.strip.blank? || data_source.blank?

      Queries::NameGenerator.generate(question:, sql:, data_source:)
    end

    def integer_value(value)
      return if value.to_s.strip.blank?
      return unless value.to_s.match?(/\A\d+\z/)

      value.to_i
    end
  end
end
