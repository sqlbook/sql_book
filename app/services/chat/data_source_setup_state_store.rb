# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module Chat
  class DataSourceSetupStateStore
    TTL = 2.hours
    METADATA_KEY = 'datasource_setup_state'
    STATE_KEYS = %w[
      name
      source_type
      host
      port
      database_name
      username
      password
      ssl_mode
      extract_category_values
      available_tables
      selected_tables
      checked_at
      next_step
    ].freeze

    def initialize(workspace:, actor:, chat_thread:)
      @workspace = workspace
      @actor = actor
      @chat_thread = chat_thread
    end

    def load
      normalize_state(read_raw_state)
    end

    def save(state)
      normalized = normalize_state(state)
      return clear! if normalized.except('next_step').blank?

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
      [
        'chat',
        'datasource_setup',
        workspace.id,
        actor.id,
        chat_thread.id
      ].join(':')
    end

    def normalize_state(state)
      raw = state.to_h.deep_stringify_keys.slice(*STATE_KEYS)
      raw['port'] = normalize_port(raw['port'])
      raw['available_tables'] = normalize_available_tables(raw['available_tables'])
      raw['selected_tables'] = Array(raw['selected_tables']).map(&:to_s).map(&:strip).compact_blank.uniq
      if raw.key?('extract_category_values')
        raw['extract_category_values'] = ActiveModel::Type::Boolean.new.cast(raw['extract_category_values'])
      end
      raw.delete_if { |key, value| value.blank? && blank_state_value?(key:, value:) }
      raw
    end

    def normalize_port(value)
      return value if value.is_a?(Integer)
      return value.to_i if value.to_s.match?(/\A\d+\z/)

      value.presence
    end

    def normalize_available_tables(groups)
      Array(groups).map do |group|
        schema = group[:schema] || group['schema']
        tables = Array(group[:tables] || group['tables']).map do |table|
          {
            'name' => (table[:name] || table['name']).to_s,
            'qualified_name' => (table[:qualified_name] || table['qualified_name']).to_s,
            'columns' => Array(table[:columns] || table['columns']).map do |column|
              {
                'name' => (column[:name] || column['name']).to_s,
                'data_type' => (column[:data_type] || column['data_type']).to_s
              }.compact
            end
          }.compact
        end

        {
          'schema' => schema.to_s,
          'tables' => tables
        }
      end
    end

    def blank_state_value?(key:, value:)
      return false if key == 'extract_category_values' && value == false
      return false if key.in?(%w[available_tables selected_tables]) && value == []

      true
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
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
