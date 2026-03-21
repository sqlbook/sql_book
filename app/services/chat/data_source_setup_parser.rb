# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength
module Chat
  class DataSourceSetupParser
    HOST_REGEX = /\b(?:host|hostname|server)\s*(?:is|=|:)\s*([^,;\n]+)/i
    DATABASE_NAME_REGEX = /\b(?:database(?:\s+name)?|dbname|db)\s*(?:is|=|:)\s*([^,;\n]+)/i
    USERNAME_REGEX = /\b(?:username|user)\s*(?:is|=|:)\s*([^,;\n]+)/i
    PASSWORD_REGEX = /\b(?:password|pass)\s*(?:is|=|:)\s*("[^"]+"|'[^']+'|[^,;\n]+)/i
    PORT_REGEX = /\bport\s*(?:is|=|:)?\s*(\d{2,5})\b/i
    SSL_MODE_REGEX = /\bssl(?:\s+mode)?\s*(?:is|=|:)\s*(disable|allow|prefer|require|verify-ca|verify-full)\b/i
    POSTGRES_REGEX = /\bpostgres(?:ql)?\b/i
    UNSUPPORTED_SOURCE_REGEX = /\b(mysql|mariadb|snowflake|bigquery|redshift|sqlite|duckdb|clickhouse|mongodb)\b/i
    NAME_PATTERNS = [
      /\b(?:call(?:\s+it)?|it(?:'s| is)\s+called)\s+["']?([^,;\n"']+)["']?/i,
      /\b(?:called|named|name\s+is|name\s+it\s+to)\s+["']?([^,;\n"']+)["']?/i,
      /\bdata\s+source\s+["']?([^,;\n"']+)["']?/i,
      /\bdatabase\s+["']?([^,;\n"']+)["']?/i
    ].freeze
    PASSWORD_PLACEHOLDER = '[Datasource password provided]'

    def initialize(message_text:, current_state: {})
      @message_text = message_text.to_s.strip
      @current_state = current_state.to_h.deep_stringify_keys
    end

    def attributes
      {
        'source_type' => parsed_source_type,
        'unsupported_source_type' => unsupported_source_type,
        'name' => parsed_name,
        'host' => parsed_value(HOST_REGEX),
        'database_name' => parsed_value(DATABASE_NAME_REGEX),
        'username' => parsed_value(USERNAME_REGEX),
        'password' => parsed_password,
        'port' => parsed_port,
        'ssl_mode' => parsed_ssl_mode
      }.compact_blank
    end

    def selected_tables
      return [] if available_table_lookup.empty?
      if all_tables_selected?
        return available_table_lookup.values.pluck('qualified_name').first(DataSource::MAX_SELECTED_TABLES)
      end

      (explicit_matches + unique_table_name_matches).uniq
    end

    def contains_connection_details?
      message_text.match?(HOST_REGEX) ||
        message_text.match?(DATABASE_NAME_REGEX) ||
        message_text.match?(USERNAME_REGEX) ||
        message_text.match?(PASSWORD_REGEX) ||
        message_text.match?(PORT_REGEX)
    end

    def contains_table_selection?
      all_tables_selected? || selected_tables.any?
    end

    def sanitized_message(password_required_only: false)
      return PASSWORD_PLACEHOLDER if password_required_only && password_like_freeform_answer?

      message_text.gsub(PASSWORD_REGEX) do |match|
        match.sub(Regexp.last_match(1), '[REDACTED]')
      end
    end

    private

    attr_reader :message_text, :current_state

    def parsed_source_type
      return 'postgres' if message_text.match?(POSTGRES_REGEX)

      nil
    end

    def unsupported_source_type
      message_text[UNSUPPORTED_SOURCE_REGEX]&.downcase
    end

    def parsed_name
      NAME_PATTERNS.each do |pattern|
        match = message_text.match(pattern)
        next unless match

        value = normalize_value(match[1])
        return value if value.present?
      end

      nil
    end

    def parsed_value(regex)
      match = message_text.match(regex)
      return nil unless match

      normalize_value(match[1])
    end

    def parsed_password
      value = parsed_value(PASSWORD_REGEX)
      return nil if value.blank?

      unquote(value)
    end

    def parsed_port
      match = message_text.match(PORT_REGEX)
      return nil unless match

      match[1].to_i
    end

    def parsed_ssl_mode
      match = message_text.match(SSL_MODE_REGEX)
      return nil unless match

      match[1].to_s.downcase
    end

    def all_tables_selected?
      message_text.match?(/\b(all\s+tables|all\s+of\s+them|everything|all)\b/i)
    end

    def explicit_matches
      available_table_lookup.values.filter_map do |table|
        qualified_name = table['qualified_name']
        next if qualified_name.blank?
        next unless message_text.match?(/\b#{Regexp.escape(qualified_name)}\b/i)

        qualified_name
      end.uniq
    end

    def unique_table_name_matches
      table_name_groups.filter_map do |_name, tables|
        next unless tables.one?
        next unless message_text.match?(/\b#{Regexp.escape(tables.first['name'])}\b/i)

        tables.first['qualified_name']
      end.uniq
    end

    def table_name_groups
      @table_name_groups ||= available_table_lookup.values.group_by { |table| table['name'].to_s.downcase }
    end

    def available_table_lookup
      @available_table_lookup ||= Array(current_state['available_tables']).each_with_object({}) do |group, lookup|
        Array(group['tables'] || group[:tables]).each do |table|
          qualified_name = (table['qualified_name'] || table[:qualified_name]).to_s
          next if qualified_name.blank?

          lookup[qualified_name.downcase] = table.stringify_keys
        end
      end
    end

    def normalize_value(value)
      value.to_s.strip.presence
    end

    def unquote(value)
      value.to_s.gsub(/\A["']|["']\z/, '')
    end

    def password_like_freeform_answer?
      return false if message_text.blank?
      return false if contains_connection_details?
      return false if message_text.include?('?')
      return false if message_text.split.size > 4

      true
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength
