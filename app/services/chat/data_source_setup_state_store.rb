# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module Chat
  class DataSourceSetupStateStore
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
      raw_state = read_raw_state
      return {} if raw_state.blank?

      normalize_state(raw_state)
    end

    def save(state)
      normalized = normalize_state(state)
      return clear! if normalized.except('next_step').blank?

      pending_follow_up_manager.replace!(
        kind: 'datasource_setup',
        domain: 'datasource',
        payload: normalized
      )
      normalized
    end

    def clear!
      pending_follow_up_manager.clear_kind!('datasource_setup')
      {}
    end

    private

    attr_reader :workspace, :actor, :chat_thread

    def normalize_state(state)
      raw = state.to_h.deep_stringify_keys.slice(*STATE_KEYS)
      return {} if raw.blank?

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
      follow_up = pending_follow_up_manager.active_payload
      return {} unless follow_up['kind'] == 'datasource_setup'

      follow_up['payload'].to_h.deep_stringify_keys
    end

    def pending_follow_up_manager
      @pending_follow_up_manager ||= PendingFollowUpManager.new(
        workspace:,
        chat_thread:,
        actor:
      )
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
