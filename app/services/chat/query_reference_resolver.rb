# frozen_string_literal: true

module Chat
  class QueryReferenceResolver # rubocop:disable Metrics/ClassLength
    DIRECT_REFERENCE_REGEX = /
      \b(this|that|same)\s+(?:query|one)\b|
      \bit\b
    /ix
    OTHER_REFERENCE_REGEX = /\b(other|another)\s+query\b/i
    ORDINAL_REFERENCE_MAP = {
      'first' => 0,
      'second' => 1,
      'third' => 2,
      'last' => -1
    }.freeze
    RECENT_RENAME_PROMPT_REGEXES = [
      /\brename\s+(?<name>.+?)\s+to\?/i,
      /\brenombrar\s+(?<name>.+?)\??\s*\z/i
    ].freeze

    def initialize(workspace:, query_references: [], recent_query_state: {}, conversation_messages: [])
      @workspace = workspace
      @query_references = Array(query_references).map { |reference| reference.to_h.deep_stringify_keys }
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

    attr_reader :workspace, :query_references, :recent_query_state, :conversation_messages

    def resolve_from_query_id(payload)
      query_id = payload['query_id'].to_i if payload['query_id'].present?
      return nil unless query_id

      saved_queries.find { |query| query.id == query_id }
    end

    def resolve_from_query_name(raw_name)
      query_name = normalized_name(raw_name)
      return nil if query_name.blank?

      reference_match = resolve_from_reference_name(query_name)
      return reference_match if reference_match

      matches = saved_queries.select { |query| normalized_name(query.name) == query_name }
      matches.one? ? matches.first : nil
    end

    def resolve_from_reference_name(query_name)
      matches = query_references.filter_map do |reference|
        next unless reference_matches_name?(reference:, query_name:)
        next if reference['saved_query_id'].to_s.strip.blank?

        resolve_from_query_id('query_id' => reference['saved_query_id'])
      end.compact.uniq

      matches.one? ? matches.first : nil
    end

    def resolve_from_text(raw_text)
      text = raw_text.to_s.strip
      return nil if text.blank?

      resolve_from_query_mentions(text) ||
        resolve_from_ordinal_reference(text) ||
        resolve_from_direct_reference(text) ||
        resolve_from_other_reference(text)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def resolve_from_query_mentions(text)
      matches = query_references.filter_map do |reference|
        next unless reference_mentioned_in_text?(reference:, text:)
        next if reference['saved_query_id'].to_s.strip.blank?

        resolve_from_query_id('query_id' => reference['saved_query_id'])
      end.compact.uniq

      if matches.empty?
        matches = saved_queries.select do |query|
          normalized_query_name = normalized_name(query.name)
          next false if normalized_query_name.blank?

          text.match?(query_name_regex(normalized_query_name))
        end
      end

      matches.one? ? matches.first : nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    def resolve_from_direct_reference(text)
      return nil unless text.match?(DIRECT_REFERENCE_REGEX)

      recent_listed_query ||
        recent_saved_query_reference_match ||
        resolve_from_query_name(recent_query_state['saved_query_name'])
    end

    def resolve_from_other_reference(text)
      return nil unless text.match?(OTHER_REFERENCE_REGEX)

      current_query_name = normalized_name(recent_saved_query_name)
      return nil if current_query_name.blank?

      candidates = ordered_saved_query_candidates.reject { |query| normalized_name(query.name) == current_query_name }
      candidates.one? ? candidates.first : nil
    end

    def resolve_from_ordinal_reference(text)
      ordinal_index = ordinal_reference_index_for(text)
      return nil if ordinal_index.nil?

      candidates = ordered_saved_query_candidates
      return nil if candidates.empty?

      candidates[ordinal_index]
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

    def recent_listed_query
      queries = recent_listed_queries
      return nil unless queries.one?

      resolve_from_query_id('query_id' => queries.first['id'])
    end

    def recent_saved_query_reference_match
      reference = query_references.find { |candidate| candidate['saved_query_id'].present? }
      return nil unless reference

      resolve_from_query_id('query_id' => reference['saved_query_id'])
    end

    # rubocop:disable Metrics/AbcSize
    def ordered_saved_query_candidates
      listed_queries = recent_listed_queries.filter_map do |query|
        resolve_from_query_id('query_id' => query['id'])
      end.compact
      return listed_queries if listed_queries.any?

      referenced_queries = query_references.filter_map do |reference|
        next if reference['saved_query_id'].to_s.strip.blank?

        resolve_from_query_id('query_id' => reference['saved_query_id'])
      end.compact
      return referenced_queries if referenced_queries.any?

      saved_queries
    end
    # rubocop:enable Metrics/AbcSize

    def recent_saved_query_name
      query_references.find { |reference| reference['saved_query_id'].present? }.to_h['saved_query_name'] ||
        recent_query_state['saved_query_name']
    end

    def recent_listed_queries
      conversation_messages.reverse_each do |entry|
        next unless assistant_entry?(entry)

        queries = listed_queries_from(entry:)
        return queries if queries.any?
      end

      []
    end

    def assistant_entry?(entry)
      (entry[:role].presence || entry['role'].presence) == 'assistant'
    end

    def listed_queries_from(entry:)
      Array(result_data(entry)['queries'] || result_data(entry)[:queries]).map do |query|
        query.to_h.deep_stringify_keys
      end
    end

    def result_data(entry)
      metadata = entry[:metadata].presence || entry['metadata'].presence || {}
      metadata['result_data'] || metadata[:result_data] || {}
    end

    def saved_queries
      @saved_queries ||= Queries::LibraryService.new(workspace:).call.to_a
    end

    def reference_matches_name?(reference:, query_name:)
      reference_names(reference:).any? { |candidate| normalized_name(candidate) == query_name }
    end

    def reference_mentioned_in_text?(reference:, text:)
      reference_names(reference:).any? do |candidate|
        normalized_candidate = normalized_name(candidate)
        next false if normalized_candidate.blank?

        text.match?(query_name_regex(normalized_candidate))
      end
    end

    def reference_names(reference:)
      [
        reference['current_name'],
        reference['saved_query_name'],
        reference['original_question'],
        *Array(reference['name_aliases'])
      ].compact_blank.uniq
    end

    def ordinal_reference_index_for(text)
      ORDINAL_REFERENCE_MAP.each do |label, index|
        return index if text.match?(/\b#{Regexp.escape(label)}\s+(?:query|one)\b/i)
      end

      nil
    end

    def normalized_name(value)
      value.to_s.strip.gsub(/\s+/, ' ').downcase.presence
    end

    def strip_formatting(value)
      value.to_s.strip.delete('*').gsub(/\A["']|["']\z/, '').squish.presence
    end
  end
end
