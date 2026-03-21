# frozen_string_literal: true

module Chat
  class QueryReferenceResolver # rubocop:disable Metrics/ClassLength
    DIRECT_REFERENCE_REGEX = /\b(this|that|same)\s+query\b/i
    OTHER_REFERENCE_REGEX = /\b(other|another)\s+query\b/i
    RECENT_RENAME_PROMPT_REGEXES = [
      /\brename\s+(?<name>.+?)\s+to\?/i,
      /\brenombrar\s+(?<name>.+?)\??\s*\z/i
    ].freeze

    def initialize(workspace:, recent_query_state: {}, conversation_messages: [])
      @workspace = workspace
      @recent_query_state = recent_query_state.to_h.deep_stringify_keys
      @conversation_messages = Array(conversation_messages).compact
    end

    def resolve(payload: nil, text: nil)
      payload_hash = payload.to_h.deep_stringify_keys

      resolve_from_query_id(payload_hash) ||
        resolve_from_query_name(payload_hash['query_name']) ||
        resolve_from_text(text) ||
        resolve_from_recent_rename_prompt
    end

    def reference_payload(payload: nil, text: nil)
      query = resolve(payload:, text:)
      return {} unless query

      {
        'query_id' => query.id,
        'query_name' => query.name
      }
    end

    private

    attr_reader :workspace, :recent_query_state, :conversation_messages

    def resolve_from_query_id(payload)
      query_id = payload['query_id'].to_i if payload['query_id'].present?
      return nil unless query_id

      saved_queries.find { |query| query.id == query_id }
    end

    def resolve_from_query_name(raw_name)
      query_name = normalized_name(raw_name)
      return nil if query_name.blank?

      matches = saved_queries.select { |query| normalized_name(query.name) == query_name }
      matches.one? ? matches.first : nil
    end

    def resolve_from_text(raw_text)
      text = raw_text.to_s.strip
      return nil if text.blank?

      resolve_from_query_mentions(text) ||
        resolve_from_direct_reference(text) ||
        resolve_from_other_reference(text)
    end

    def resolve_from_query_mentions(text)
      matches = saved_queries.select do |query|
        normalized_query_name = normalized_name(query.name)
        next false if normalized_query_name.blank?

        text.match?(query_name_regex(normalized_query_name))
      end

      matches.one? ? matches.first : nil
    end

    def resolve_from_direct_reference(text)
      return nil unless text.match?(DIRECT_REFERENCE_REGEX)

      resolve_from_query_name(recent_query_state['saved_query_name'])
    end

    def resolve_from_other_reference(text)
      return nil unless text.match?(OTHER_REFERENCE_REGEX)

      current_query_name = normalized_name(recent_query_state['saved_query_name'])
      return nil if current_query_name.blank?

      candidates = saved_queries.reject { |query| normalized_name(query.name) == current_query_name }
      candidates.one? ? candidates.first : nil
    end

    def resolve_from_recent_rename_prompt
      query_name = recent_rename_prompt_query_name
      return nil if query_name.blank?

      resolve_from_query_name(query_name)
    end

    def recent_rename_prompt_query_name
      assistant_content = recent_assistant_content
      return nil if assistant_content.blank?

      RECENT_RENAME_PROMPT_REGEXES.each do |pattern|
        match = assistant_content.match(pattern)
        next unless match

        cleaned_name = strip_formatting(match[:name])
        return cleaned_name if cleaned_name.present?
      end

      nil
    end

    def recent_assistant_content
      assistant_message = conversation_messages.reverse.find do |entry|
        role = entry[:role].presence || entry['role'].presence
        role == 'assistant'
      end
      return nil unless assistant_message

      assistant_message[:content].presence || assistant_message['content'].presence
    end

    def query_name_regex(query_name)
      /\b#{Regexp.escape(query_name)}\b/i
    end

    def saved_queries
      @saved_queries ||= Queries::LibraryService.new(workspace:).call.to_a
    end

    def normalized_name(value)
      value.to_s.strip.gsub(/\s+/, ' ').downcase.presence
    end

    def strip_formatting(value)
      value.to_s.strip.delete('*').gsub(/\A["']|["']\z/, '').squish.presence
    end
  end
end
