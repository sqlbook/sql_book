# frozen_string_literal: true

module Chat
  class QuerySaveNameConflictStateStore
    TTL = 2.hours
    METADATA_KEY = 'query_save_name_conflict_state'
    STATE_KEYS = %w[
      sql
      question
      data_source_id
      data_source_name
      proposed_name
      conflicting_query_id
      conflicting_query_name
    ].freeze

    def initialize(workspace:, actor:, chat_thread:)
      @workspace = workspace
      @actor = actor
      @chat_thread = chat_thread
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

    attr_reader :workspace, :actor, :chat_thread

    def cache_key
      ['chat', 'query_save_name_conflict', workspace.id, actor.id, chat_thread.id].join(':')
    end

    def normalize(state)
      raw = state.to_h.deep_stringify_keys.slice(*STATE_KEYS)
      normalize_integer_fields!(raw, keys: %w[data_source_id conflicting_query_id])
      raw.compact_blank!
      raw
    end

    def normalize_integer_fields!(raw, keys:)
      Array(keys).each do |key|
        raw[key] = raw[key].to_i if raw[key].to_s.match?(/\A\d+\z/)
      end
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
      chat_thread.has_attribute?(:metadata)
    end

    def update_thread_metadata
      metadata = chat_thread.reload.metadata.to_h.deep_stringify_keys
      yield metadata
      chat_thread.update!(metadata:)
    end
  end
end
