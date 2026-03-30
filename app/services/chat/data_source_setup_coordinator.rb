# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
module Chat
  class DataSourceSetupCoordinator
    Resolution = Struct.new(
      :status,
      :assistant_message,
      :action_type,
      :payload,
      :sanitized_user_content,
      keyword_init: true
    )

    START_REGEX = /
      \b(add|create|connect|configure|set\s*up|setup|help)\b.*\b(data\s+source|database|postgres(?:ql)?)\b
    /ix
    FIELD_KEYWORDS_REGEX = /
      \b(host|hostname|server|database|dbname|db|username|user|password|pass|port|ssl|table|tables)\b
    /ix
    QUERY_LIKE_REGEX = /\b(how\ many|count|total|show|list|find|get|query|sql|select|with|who|rows?)\b/i
    QUESTION_LIKE_REGEX = /\A\s*(?:what|when|where|who|why|how|do|does|did|can|could|would|is|are|tell)\b/i
    CONNECTION_FIELDS = %w[host database_name username password].freeze

    delegate :clear!, to: :state_store

    def initialize(workspace:, actor:, chat_thread:, message_text:)
      @workspace = workspace
      @actor = actor
      @chat_thread = chat_thread
      @message_text = message_text.to_s.strip
    end

    def call
      @state = state_store.load
      return unless applicable?

      merge_parsed_attributes!
      return unsupported_source_resolution if unsupported_source_type.present?

      state['source_type'] ||= 'postgres'
      apply_freeform_follow_up!
      state['next_step'] = next_step

      if state['name'].blank?
        persist_state!
        return ask(I18n.t('app.workspaces.chat.datasource_setup.ask_name'))
      end

      if missing_connection_fields.any?
        persist_state!
        return ask(connection_prompt)
      end

      if state['available_tables'].blank?
        persist_state!
        return action('datasource.validate_connection', validation_payload)
      end

      if state['selected_tables'].blank?
        persist_state!
        return ask(table_selection_prompt)
      end

      persist_state!
      action('datasource.create', create_payload)
    end

    def apply_validation_success(execution:)
      current = state_store.load
      current['available_tables'] = normalize_available_tables(
        execution.data.to_h['available_tables'] || execution.data.to_h[:available_tables] || []
      )
      current['checked_at'] = execution.data.to_h['checked_at'] || execution.data.to_h[:checked_at]
      current['next_step'] = 'tables'
      state_store.save(current)

      ask(table_selection_prompt(state: current))
    end

    private

    attr_reader :workspace, :actor, :chat_thread, :message_text, :state

    def applicable?
      return true if starting_setup_request?
      return false if state.blank?

      case state['next_step']
      when 'name'
        parser.attributes['name'].present? || plain_follow_up_answer?
      when 'connection'
        parser.contains_connection_details? || single_missing_connection_field_answer?
      when 'tables'
        parser.contains_table_selection? || plain_follow_up_answer?
      else
        false
      end
    end

    def merge_parsed_attributes!
      parsed_attributes = parser.attributes.except('unsupported_source_type').compact_blank
      parsed_attributes.delete('name') if state['name'].present?
      state.merge!(parsed_attributes)
      selected_tables = parser.selected_tables
      state['selected_tables'] = selected_tables if selected_tables.any?
    end

    def unsupported_source_resolution
      clear!
      ask(I18n.t('app.workspaces.chat.datasource_setup.only_postgres', source_type: unsupported_source_type))
    end

    def apply_freeform_follow_up!
      state['name'] = message_text if state['name'].blank? && next_step == 'name' && plain_follow_up_answer?

      if state['next_step'] == 'connection' && missing_connection_fields.one? && single_missing_connection_field_answer?
        field = missing_connection_fields.first
        state[field] = normalized_freeform_value(field)
      end

      return unless state['next_step'] == 'tables' && state['selected_tables'].blank? && plain_follow_up_answer?

      state['selected_tables'] = parser.selected_tables
    end

    def normalized_freeform_value(field)
      return message_text.to_i if field == 'port' && message_text.match?(/\A\d+\z/)

      message_text
    end

    def next_step
      return 'name' if state['name'].blank?
      return 'connection' if missing_connection_fields.any?
      return 'tables' if state['available_tables'].blank? || state['selected_tables'].blank?

      'create'
    end

    def missing_connection_fields
      CONNECTION_FIELDS.select { |field| state[field].to_s.strip.blank? }
    end

    def validation_payload
      {
        'host' => state['host'],
        'port' => normalized_port,
        'database_name' => state['database_name'],
        'username' => state['username'],
        'password' => state['password'],
        'ssl_mode' => state['ssl_mode']
      }.compact_blank
    end

    def create_payload
      validation_payload.merge(
        'name' => state['name'],
        'selected_tables' => Array(state['selected_tables'])
      )
    end

    def normalized_port
      return nil if state['port'].blank?
      return state['port'] if state['port'].is_a?(Integer)
      return state['port'].to_i if state['port'].to_s.match?(/\A\d+\z/)

      state['port']
    end

    def connection_prompt
      missing_labels = missing_connection_fields.map do |field|
        I18n.t("app.workspaces.chat.datasource_setup.fields.#{field}")
      end

      I18n.t(
        'app.workspaces.chat.datasource_setup.ask_connection_details',
        missing_fields: missing_labels.to_sentence,
        default_port: DataSource::POSTGRES_DEFAULT_PORT
      )
    end

    def table_selection_prompt(state: self.state)
      available_tables = normalize_available_tables(state['available_tables'])
      total_tables = available_tables.sum { |group| Array(group['tables']).size }
      preview = available_tables.flat_map { |group| Array(group['tables']) }
        .first(8)
        .map { |table| table['qualified_name'].presence || table['name'] }
        .compact
        .join(', ')

      I18n.t(
        'app.workspaces.chat.datasource_setup.ask_tables',
        table_count: total_tables,
        tables_preview: preview,
        default_message: I18n.t('app.workspaces.chat.datasource_setup.ask_tables_fallback')
      )
    end

    def ask(message)
      Resolution.new(
        status: 'ask',
        assistant_message: message,
        action_type: nil,
        payload: {},
        sanitized_user_content: sanitized_user_content
      )
    end

    def action(action_type, payload)
      Resolution.new(
        status: 'action',
        assistant_message: nil,
        action_type: action_type,
        payload: payload,
        sanitized_user_content: sanitized_user_content
      )
    end

    def persist_state!
      state_store.save(state)
    end

    def sanitized_user_content
      return @sanitized_user_content if defined?(@sanitized_user_content)

      password_required_only = state['next_step'] == 'connection' && missing_connection_fields == ['password']
      sanitized = parser.sanitized_message(password_required_only:)
      @sanitized_user_content = sanitized == message_text ? nil : sanitized
    end

    def state_store
      @state_store ||= DataSourceSetupStateStore.new(workspace:, actor:, chat_thread:)
    end

    def parser
      @parser ||= DataSourceSetupParser.new(message_text:, current_state: state)
    end

    def unsupported_source_type
      parser.attributes['unsupported_source_type']
    end

    def starting_setup_request?
      return false if message_text.match?(QUERY_LIKE_REGEX)
      return true if message_text.match?(START_REGEX)

      message_text.match?(FIELD_KEYWORDS_REGEX) && message_text.match?(/\b(data\s+source|database|postgres(?:ql)?)\b/i)
    end

    def plain_follow_up_answer?
      return false if message_text.blank?
      return false if message_text.match?(QUESTION_LIKE_REGEX)
      return false if message_text.include?('?')

      true
    end

    def single_missing_connection_field_answer?
      plain_follow_up_answer? && missing_connection_fields.one?
    end

    def normalize_available_tables(available_tables)
      JSON.parse(Array(available_tables).to_json)
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
