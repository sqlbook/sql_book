# frozen_string_literal: true

require 'json'
require 'net/http'

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
module Chat
  class QuerySqlPlanner
    Plan = Struct.new(:sql, :clarification_question, keyword_init: true)

    CHAT_MODEL_FALLBACK = 'gpt-4.1-mini'
    STOPWORDS = %w[
      a an and are as at by for from give have how i in is it list me my of on
      run show sql tell the to total what which with cuantos cuantas dame lista
      mostrar muéstrame tengo
    ].freeze
    SEMANTIC_HINTS = {
      'user' => {
        tables: %w[user users account accounts member members profile profiles customer customers person people],
        columns: %w[email user_id member_id account_id first_name last_name full_name]
      }
    }.freeze
    REFINEMENT_REQUEST_REGEX = /
      \b(
        tweak|adjust|update|change|modify|refine|instead|also|split|group|
        break(?:\s+it)?\s+down|filter
      )\b
    /ix
    GROUPING_REQUEST_REGEX = /
      \b(
        split|group(?:ed)?|break(?:\s+it)?\s+down|by
      )\b
    /ix
    IDENTITY_REQUEST_REGEX = /
      \b(
        who\s+are|who\s+they\s+are|just\s+who\s+they\s+are|list\s+users|show\s+users|all\s+users
      )\b
    /ix

    def initialize(question:, data_source:, schema:, preferred_table: nil, refinement_context: {})
      @question = question.to_s.strip
      @data_source = data_source
      @schema = Array(schema)
      @preferred_table = preferred_table.to_s.presence
      @refinement_context = refinement_context.to_h.deep_stringify_keys
    end

    def call
      direct_sql_plan || llm_plan || heuristic_plan || clarification_plan
    rescue StandardError => e
      Rails.logger.warn("Chat query SQL planning failed: #{e.class} #{e.message}")
      heuristic_plan || clarification_plan
    end

    private

    attr_reader :question, :data_source, :schema, :preferred_table, :refinement_context

    def base_sql
      refinement_context['base_sql'].to_s.strip
    end

    def base_question
      refinement_context['base_question'].to_s.strip
    end

    def base_query_name
      refinement_context['base_query_name'].to_s.strip
    end

    def direct_sql_plan
      return nil unless question.match?(/\A\s*(select|with)\b/i)

      DataSources::QuerySafetyGuard.validate!(sql: question)
      Plan.new(sql: question, clarification_question: nil)
    rescue DataSources::Connectors::BaseConnector::QueryError
      clarification_plan
    end

    def llm_plan
      return nil if api_key.blank?

      chat_model_candidates.each do |model|
        response = perform_request(payload: request_payload(model:))
        next unless response.is_a?(Net::HTTPSuccess)

        parsed = JSON.parse(response.body)
        body = response_text_from(parsed)
        next if body.blank?

        payload = parse_json_object(body)
        next unless payload.is_a?(Hash)

        sql = payload['sql'].to_s.strip.presence
        clarification_question = payload['clarification_question'].to_s.strip.presence
        DataSources::QuerySafetyGuard.validate!(sql:) if sql.present?
        return Plan.new(sql:, clarification_question:)
      rescue JSON::ParserError, DataSources::Connectors::BaseConnector::QueryError => e
        Rails.logger.warn("Chat query SQL planner parse failed (model=#{model}): #{e.class} #{e.message}")
      end

      nil
    end

    def heuristic_plan
      refinement_sql = refinement_heuristic_sql
      return Plan.new(sql: refinement_sql, clarification_question: nil) if refinement_sql.present?

      table = preferred_table.presence || heuristic_table_match
      return nil if table.blank?

      normalized = question.downcase
      sql = if normalized.match?(/\b(how many|count|number of|total)\b/)
              count_query_sql_for(table:)
            elsif identity_request?(normalized)
              identity_select_sql_for(table:) || "SELECT * FROM #{table} ORDER BY 1 LIMIT 25"
            elsif normalized.match?(/\b(show|list|find|get)\b/)
              "SELECT * FROM #{table} ORDER BY 1 LIMIT 25"
            end
      return nil if sql.blank?

      DataSources::QuerySafetyGuard.validate!(sql: sql)
      Plan.new(sql:, clarification_question: nil)
    rescue DataSources::Connectors::BaseConnector::QueryError
      nil
    end

    def refinement_heuristic_sql
      letter_variant_sql = letter_variant_refinement_sql
      return letter_variant_sql if letter_variant_sql.present?

      return nil unless refinement_request?
      return nil unless base_sql.present? && base_sql.match?(/\bcount\s*\(/i)
      return nil unless question.downcase.match?(GROUPING_REQUEST_REGEX)

      table = prior_table_name.presence || preferred_table.presence || heuristic_table_match
      return nil if table.blank?

      grouping_column = grouping_column_for(table:)
      return nil if grouping_column.blank?

      count_alias = count_alias_from(sql: base_sql) || 'count'
      sql = [
        "SELECT #{grouping_column}, COUNT(*) AS #{count_alias}",
        "FROM #{table}",
        "GROUP BY #{grouping_column}",
        "ORDER BY #{grouping_column}"
      ].join("\n")
      DataSources::QuerySafetyGuard.validate!(sql:)
      sql
    rescue DataSources::Connectors::BaseConnector::QueryError
      nil
    end

    def clarification_plan
      Plan.new(
        sql: nil,
        clarification_question: I18n.t('app.workspaces.chat.query.ask_for_table_or_metric')
      )
    end

    def identity_request?(normalized_question)
      normalized_question.match?(IDENTITY_REQUEST_REGEX)
    end

    def refinement_request?
      question.downcase.match?(REFINEMENT_REQUEST_REGEX) || QueryFollowUpMatcher.contextual_follow_up?(
        text: question,
        recent_query_reference: { 'sql' => base_sql }
      )
    end

    def count_query_sql_for(table:)
      letter_filter_clause = letter_filter_clause_for(table:)
      return "SELECT COUNT(*) AS count FROM #{table}" if letter_filter_clause.blank?

      [
        'SELECT COUNT(*) AS count',
        "FROM #{table}",
        "WHERE #{letter_filter_clause}"
      ].join("\n")
    end

    def letter_filter_clause_for(table:)
      letter = QueryFollowUpMatcher.letter_variant(text: question)
      return nil if letter.blank?

      table_entry = flattened_tables.find { |candidate| candidate['qualified_name'] == table }
      return nil unless table_entry

      available_columns = Array(table_entry['columns']).map do |column|
        (column[:name] || column['name']).to_s
      end
      target_column = if question.downcase.include?('first name')
                        available_columns.find { |name| name.casecmp('first_name').zero? }
                      elsif question.downcase.include?('last name')
                        available_columns.find { |name| name.casecmp('last_name').zero? }
                      else
                        available_columns.find { |name| name.casecmp('name').zero? } ||
                          available_columns.find { |name| name.casecmp('full_name').zero? } ||
                          available_columns.find { |name| name.casecmp('first_name').zero? }
                      end
      return nil if target_column.blank?

      "#{target_column} ILIKE '%#{letter}%'"
    end

    def letter_variant_refinement_sql
      return nil unless refinement_request?
      return nil if base_sql.blank?

      letter = QueryFollowUpMatcher.letter_variant(text: question)
      return nil if letter.blank?
      return nil unless base_sql.match?(/\bilike\s+'%[^']+%'/i)

      sql = base_sql.sub(/\bilike\s+'%[^']+%'/i, "ILIKE '%#{letter}%'")
      return nil if sql == base_sql

      DataSources::QuerySafetyGuard.validate!(sql:)
      sql
    rescue DataSources::Connectors::BaseConnector::QueryError
      nil
    end

    def identity_select_sql_for(table:)
      columns = identity_projection_for(table:)
      return nil if columns.empty?

      "SELECT #{columns.join(', ')} FROM #{table} ORDER BY 1 LIMIT 25"
    end

    def identity_projection_for(table:)
      table_entry = flattened_tables.find { |candidate| candidate['qualified_name'] == table }
      return [] unless table_entry

      available_columns = Array(table_entry['columns']).map do |column|
        (column[:name] || column['name']).to_s
      end
      return [] if available_columns.empty?

      preferred_columns_for(available_columns:)
    end

    def preferred_columns_for(available_columns:)
      available_lookup = available_columns.index_by(&:downcase)
      projection = []

      if available_lookup.key?('full_name')
        projection << available_lookup['full_name']
      elsif available_lookup.key?('name')
        projection << available_lookup['name']
      else
        %w[first_name last_name].each do |column_name|
          projection << available_lookup[column_name] if available_lookup.key?(column_name)
        end
      end

      projection << available_lookup['username'] if projection.empty? && available_lookup.key?('username')
      if available_lookup.key?('email') && projection.exclude?(available_lookup['email'])
        projection << available_lookup['email']
      end
      projection = available_columns.first(3) if projection.empty?
      projection.first(3)
    end

    def heuristic_table_match
      return preferred_table if preferred_table.present?
      return flattened_tables.first['qualified_name'] if flattened_tables.one?

      scored_tables = flattened_tables.filter_map do |table|
        score = relevance_score_for(table:)
        next if score.zero?

        [table['qualified_name'], score]
      end
      return nil if scored_tables.empty?

      scored_tables.max_by(&:last).first
    end

    def prior_table_name
      @prior_table_name ||= table_name_from(sql: Queries::Fingerprint.normalize_sql(base_sql).to_s)
    end

    def grouping_column_for(table:)
      table_entry = flattened_tables.find { |candidate| candidate['qualified_name'] == table }
      return nil unless table_entry

      Array(table_entry['columns'])
        .map { |column| (column[:name] || column['name']).to_s }
        .filter_map do |column_name|
          score = grouping_column_score(column_name:)
          next if score.zero?

          [column_name, score]
        end
        .max_by(&:last)
        &.first
    end

    def grouping_column_score(column_name:)
      column_tokens = column_name.downcase.split(/[^a-z0-9]+/).compact_blank
      return 0 if column_tokens.empty?

      overlap = question_tokens.count { |token| column_tokens.include?(token) }
      overlap += 2 if question.downcase.include?(column_name.downcase.tr('_', ' '))
      overlap += 2 if question.downcase.include?(column_name.downcase)
      overlap
    end

    def count_alias_from(sql:)
      sql.to_s.match(/\bcount\s*\(\s*\*\s*\)\s+as\s+("?[\w]+"?)/i)&.captures&.first.to_s.delete('"').presence
    end

    def relevance_score_for(table:)
      tokens = question_tokens
      table_name = table['name'].to_s.downcase
      qualified_name = table['qualified_name'].to_s.downcase
      column_names = Array(table['columns']).map { |column| (column[:name] || column['name']).to_s.downcase }

      token_score = tokens.sum do |token|
        if table_matches_token?(qualified_name:, table_name:, token:)
          4
        elsif column_names.any? { |column| column.include?(token) }
          1
        else
          0
        end
      end

      token_score + semantic_table_bonus(
        table_name:,
        qualified_name:,
        column_names:
      )
    end

    def question_tokens
      @question_tokens ||= question.downcase.scan(/[a-z][a-z0-9_]+/).reject do |token|
        STOPWORDS.include?(token)
      end.uniq
    end

    def semantic_table_bonus(table_name:, qualified_name:, column_names:)
      SEMANTIC_HINTS.sum do |keyword, hints|
        next 0 unless question.downcase.match?(/\b#{Regexp.escape(keyword)}s?\b/)

        bonus = 0
        bonus += 6 if [table_name, qualified_name].any? { |name| hints[:tables].any? { |hint| name.include?(hint) } }
        bonus += 2 if Array(column_names).any? { |column| hints[:columns].any? { |hint| column.include?(hint) } }
        bonus
      end
    end

    def flattened_tables
      @flattened_tables ||= begin
        tables = schema.flat_map do |group|
          Array(group[:tables] || group['tables'])
        end
        tables.map do |table|
          table.is_a?(Hash) ? table.stringify_keys : {}
        end
      end
    end

    def request_payload(model:)
      {
        model:,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: user_prompt
              }
            ]
          }
        ],
        text: {
          format: {
            type: 'json_schema',
            name: 'sqlbook_query_sql_plan',
            schema: {
              'type' => 'object',
              'required' => %w[sql clarification_question],
              'additionalProperties' => false,
              'properties' => {
                'sql' => { 'type' => %w[string null] },
                'clarification_question' => { 'type' => %w[string null] }
              }
            },
            strict: true
          }
        }
      }
    end

    def system_prompt
      [
        'You generate safe read-only SQL for sqlbook.',
        'Use only the provided tables and columns.',
        'Never invent tables or columns.',
        'If the request is ambiguous, return clarification_question instead of guessing.',
        'Only produce SELECT or WITH statements.',
        'Do not include markdown fences or commentary.',
        'Return JSON only with keys sql and clarification_question.'
      ].join(' ')
    end

    def user_prompt
      [
        "Data source: #{data_source.display_name} (#{data_source.source_type})",
        (preferred_table.present? ? "Preferred table: #{preferred_table}" : nil),
        (base_query_context.present? ? "Previous query context:\n#{base_query_context}" : nil),
        "Question: #{question}",
        "Schema:\n#{schema_summary}"
      ].compact.join("\n\n")
    end

    def base_query_context
      lines = []
      lines << "Saved query name: #{base_query_name}" if base_query_name.present?
      lines << "Previous question: #{base_question}" if base_question.present?
      lines << "Previous SQL: #{base_sql}" if base_sql.present?
      lines.compact.join("\n")
    end

    def schema_summary
      schema.first(12).map do |group|
        schema_name = group[:schema] || group['schema']
        tables = Array(group[:tables] || group['tables']).first(12).map do |table|
          columns = Array(table[:columns] || table['columns']).first(12).map do |column|
            column_name = column[:name] || column['name']
            column_type = column[:data_type] || column['data_type']
            "#{column_name}(#{column_type})"
          end.join(', ')
          "- #{table[:qualified_name] || table['qualified_name']}: #{columns}"
        end.join("\n")
        "Schema #{schema_name}:\n#{tables}"
      end.join("\n\n")
    end

    def perform_request(payload:)
      Net::HTTP.start(
        endpoint.host,
        endpoint.port,
        use_ssl: endpoint.scheme == 'https',
        read_timeout: 18,
        open_timeout: 4
      ) do |http|
        request = Net::HTTP::Post.new(endpoint)
        request['Authorization'] = "Bearer #{api_key}"
        request['Content-Type'] = 'application/json'
        request.body = payload.to_json
        http.request(request)
      end
    end

    def response_text_from(parsed)
      direct = parsed.fetch('output_text', '').to_s.strip
      return direct if direct.present?

      Array(parsed['output']).flat_map do |output_item|
        Array(output_item['content']).filter_map do |content_item|
          raw_text = content_item['text']
          value = raw_text.is_a?(Hash) ? raw_text['value'] : raw_text
          value.to_s.strip.presence
        end
      end.join("\n").strip
    end

    def parse_json_object(raw_json)
      JSON.parse(raw_json)
    rescue JSON::ParserError
      nil
    end

    def chat_model_candidates
      configured_model = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini').to_s.strip
      candidates = [configured_model.presence || 'gpt-5-mini']
      candidates << CHAT_MODEL_FALLBACK unless candidates.include?(CHAT_MODEL_FALLBACK)
      candidates
    end

    def table_matches_token?(qualified_name:, table_name:, token:)
      qualified_name.include?(token) ||
        table_name.include?(token.singularize) ||
        table_name.include?(token.pluralize)
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
