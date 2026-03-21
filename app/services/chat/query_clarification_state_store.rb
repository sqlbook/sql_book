# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
module Chat
  class QueryClarificationStateStore
    TTL = 2.hours
    METADATA_KEY = 'query_clarification_state'
    STATE_KEYS = %w[question step data_source_id candidate_data_sources candidate_tables].freeze

    def initialize(workspace:, actor:, chat_thread: nil, chat_thread_id: nil)
      @workspace = workspace
      @actor = actor
      @chat_thread = chat_thread
      @chat_thread_id = chat_thread_id
    end

    def load
      normalize(read_raw_state)
    end

    def save(state)
      normalized = normalize(state)
      return clear! if normalized.blank?

      persist_state(normalized)
      normalized
    end

    def clear!
      clear_persisted_state
      {}
    end

    private

    attr_reader :workspace, :actor, :chat_thread_id

    def cache_key
      ['chat', 'query_clarification', workspace.id, actor.id, chat_thread_id].join(':')
    end

    def normalize(state)
      raw = state.to_h.deep_stringify_keys.slice(*STATE_KEYS)
      raw['candidate_data_sources'] = Array(raw['candidate_data_sources']).map do |candidate|
        {
          'id' => candidate[:id] || candidate['id'],
          'name' => candidate[:name] || candidate['name'],
          'source_type' => candidate[:source_type] || candidate['source_type']
        }.compact_blank
      end
      raw['candidate_tables'] = Array(raw['candidate_tables']).map do |candidate|
        {
          'qualified_name' => candidate[:qualified_name] || candidate['qualified_name'],
          'name' => candidate[:name] || candidate['name']
        }.compact_blank
      end
      raw.compact_blank!
      raw
    end

    def read_raw_state
      if metadata_supported?
        chat_thread.reload.metadata.to_h.deep_stringify_keys[METADATA_KEY] || {}
      else
        Rails.cache.read(cache_key) || {}
      end
    end

    def persist_state(normalized)
      if metadata_supported?
        update_thread_metadata do |metadata|
          metadata[METADATA_KEY] = normalized
        end
      else
        Rails.cache.write(cache_key, normalized, expires_in: TTL)
      end
    end

    def clear_persisted_state
      if metadata_supported?
        update_thread_metadata do |metadata|
          metadata.delete(METADATA_KEY)
        end
      else
        Rails.cache.delete(cache_key)
      end
    end

    def metadata_supported?
      chat_thread.present? && chat_thread.has_attribute?(:metadata)
    end

    def chat_thread
      @chat_thread ||= workspace.chat_threads.active.for_user(actor).find_by(id: chat_thread_id)
    end

    def update_thread_metadata
      metadata = chat_thread.reload.metadata.to_h.deep_stringify_keys
      yield metadata
      chat_thread.update!(metadata:)
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
