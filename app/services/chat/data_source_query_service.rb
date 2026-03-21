# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
module Chat
  class DataSourceQueryService
    Result = Struct.new(:status, :message, :data, :error_code, keyword_init: true)
    NullClarificationStore = Struct.new(:_unused) do
      def load = {}
      def save(_state) = {}
      def clear! = {}
    end

    QUERY_INTENT_REGEX = /\b(how many|count|total|average|avg|sum|max|min|show|list|find|get|query|sql|who|rows?)\b/i
    NEW_QUERY_SIGNAL_REGEX = /
      \b(
        how\ many|count|total|average|avg|sum|max|min|show|list|find|get|query|sql|select|with|who
      )\b
    /ix
    SCHEMA_INFERENCE_REGEX = /
      \b(
        tell\ from\ the\ schema|from\ the\ schema|which\ of\ those|
        which\ table|what\ table|contains\ the\ user\ data|contains\ user\ data
      )\b
    /ix
    SEMANTIC_HINTS = {
      'user' => {
        tables: %w[user users account accounts member members profile profiles customer customers person people],
        columns: %w[email user_id member_id account_id first_name last_name full_name]
      }
    }.freeze
    ORDINAL_HINTS = {
      /\bfirst\b/i => 0,
      /\bsecond\b/i => 1,
      /\bthird\b/i => 2,
      /\blast\b/i => -1
    }.freeze
    STOPWORDS = %w[
      a an and are as at by for from have how i in is it me my of on or sqlbook tell the to what which with
    ].freeze

    def initialize(workspace:, actor:, payload:)
      @workspace = workspace
      @actor = actor
      @payload = payload.to_h.deep_stringify_keys
    end

    def call # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return validation_error(I18n.t('app.workspaces.chat.query.question_required')) if current_question.blank?

      return continue_from_clarification_state if active_clarification_state.present? && !new_query_request?

      clarification_store.clear!
      data_source = resolve_data_source(current_question)
      return data_source if data_source.is_a?(Result)

      schema = schema_for(data_source)
      table_resolution = resolve_table_clarification(schema:, data_source_id: data_source.id)
      return table_resolution if table_resolution.is_a?(Result)

      preferred_table = table_resolution
      plan = QuerySqlPlanner.new(
        question: current_question,
        data_source:,
        schema:,
        preferred_table:
      ).call

      return clarification_result(question: plan.clarification_question) if plan.sql.blank?

      query_result = data_source.connector.execute_readonly(sql: plan.sql)
      clarification_store.clear!
      executed(
        message: formatted_query_result_message(data_source:, sql: plan.sql, query_result:),
        data: {
          'question' => current_question,
          'data_source' => serialize_data_source(data_source:),
          'sql' => plan.sql,
          'columns' => query_result.columns,
          'rows' => query_result.rows,
          'row_count' => query_result.rows.length
        }
      )
    rescue DataSources::Connectors::BaseConnector::ConnectionError => e
      validation_error(e.message, code: 'connection_failed')
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      validation_error(e.message, code: e.code || 'query_failed')
    end

    private

    attr_reader :workspace, :actor, :payload

    def current_question
      payload['question'].to_s.strip.presence || payload['message'].to_s.strip
    end

    def active_clarification_state
      @active_clarification_state ||= clarification_store.load
    end

    def continue_from_clarification_state
      state = active_clarification_state
      case state['step']
      when 'data_source'
        data_source = resolve_data_source_candidate_from_state(state:)
        if data_source.nil?
          return clarification_result(
            question: data_source_clarification_message(candidates: state['candidate_data_sources'])
          )
        end

        state['data_source_id'] = data_source.id
        clarification_store.save(state)
        schema = schema_for(data_source)
        table_resolution = resolve_table_clarification(
          schema:,
          question: state['question'],
          data_source_id: data_source.id
        )
        return table_resolution if table_resolution.is_a?(Result)

        clarification_store.clear!
        return execute_original_question(data_source:, question: state['question'], preferred_table: table_resolution)
      when 'table'
        data_source = workspace.data_sources.find_by(id: state['data_source_id'])
        return validation_error(I18n.t('app.workspaces.chat.query.data_source_not_found')) if data_source.nil?

        table = resolve_table_candidate_from_state(state:)
        if table.blank?
          if schema_inference_request? && Array(state['candidate_tables']).any?
            return clarification_result(
              question: schema_guidance_message(candidates: state['candidate_tables'])
            )
          end

          return clarification_result(
            question: table_clarification_message(candidates: state['candidate_tables'])
          )
        end

        clarification_store.clear!
        return execute_original_question(data_source:, question: state['question'], preferred_table: table)
      end

      clarification_store.clear!
      validation_error(I18n.t('app.workspaces.chat.query.query_failed'))
    end

    def execute_original_question(data_source:, question:, preferred_table: nil)
      schema = schema_for(data_source)
      plan = QuerySqlPlanner.new(question:, data_source:, schema:, preferred_table:).call
      return clarification_result(question: plan.clarification_question) if plan.sql.blank?

      query_result = data_source.connector.execute_readonly(sql: plan.sql)
      executed(
        message: formatted_query_result_message(data_source:, sql: plan.sql, query_result:),
        data: {
          'question' => question,
          'data_source' => serialize_data_source(data_source:),
          'sql' => plan.sql,
          'columns' => query_result.columns,
          'rows' => query_result.rows,
          'row_count' => query_result.rows.length
        }
      )
    end

    def resolve_data_source(question)
      data_sources = workspace.data_sources.active.order(:name, :id)
      return validation_error(I18n.t('app.workspaces.chat.query.no_data_sources')) if data_sources.empty?

      explicit = explicit_data_source(data_sources:)
      return explicit if explicit
      return data_sources.first if data_sources.one?

      scored = data_sources.map do |data_source|
        [data_source, data_source_score(data_source:, question:)]
      end
      positive = scored.select { |(_, score)| score.positive? }
      return clarification_for_data_sources(data_sources:) if positive.empty?

      best_score = positive.map(&:last).max
      best = positive.select { |(_, score)| score == best_score }
      return best.first.first if best.one?

      clarification_for_data_sources(data_sources: best.map(&:first))
    end

    def explicit_data_source(data_sources:)
      if payload['data_source_id'].present?
        return data_sources.find { |data_source| data_source.id == payload['data_source_id'].to_i }
      end

      explicit_name = payload['data_source_name'].to_s.strip.downcase.presence
      return nil if explicit_name.blank?

      data_sources.find { |data_source| data_source.display_name.to_s.downcase == explicit_name }
    end

    def data_source_score(data_source:, question:)
      score = 0
      normalized_question = question.downcase
      data_source_name = data_source.display_name.to_s.downcase
      score += 8 if normalized_question.include?(data_source_name)

      schema = compact_schema_for(data_source)
      tokens = question_tokens(question)
      score + schema.sum do |group|
        Array(group[:tables] || group['tables']).sum do |table|
          table_name = (table[:name] || table['name']).to_s.downcase
          qualified_name = (table[:qualified_name] || table['qualified_name']).to_s.downcase
          tokens.sum do |token|
            if table_matches_token?(qualified_name:, table_name:, token:)
              4
            else
              0
            end
          end
        end
      end
    rescue DataSources::Connectors::BaseConnector::ConnectionError
      0
    end

    def clarification_for_data_sources(data_sources:)
      candidates = data_sources.map do |data_source|
        {
          'id' => data_source.id,
          'name' => data_source.display_name,
          'source_type' => data_source.source_type
        }
      end
      clarification_store.save(
        question: current_question,
        step: 'data_source',
        candidate_data_sources: candidates
      )

      clarification_result(question: data_source_clarification_message(candidates:))
    end

    def resolve_table_clarification(schema:, question: current_question, data_source_id: nil)
      flattened_tables = flatten_tables(schema)
      return nil if flattened_tables.empty?
      return flattened_tables.first['qualified_name'] if flattened_tables.one?

      scored = flattened_tables.map { |table| [table, table_score(table:, question:)] }
      positive = scored.select { |(_, score)| score.positive? }
      return nil if positive.empty?

      best_score = positive.map(&:last).max
      best = positive.select { |(_, score)| score == best_score }
      return best.first.first['qualified_name'] if best.one?

      candidates = best.map do |(table, _score)|
        {
          'qualified_name' => table['qualified_name'],
          'name' => table['name']
        }
      end
      clarification_store.save(
        question: question,
        step: 'table',
        data_source_id: clarification_data_source_id(data_source_id:),
        candidate_tables: candidates
      )

      clarification_result(question: table_clarification_message(candidates:))
    end

    def table_score(table:, question:)
      tokens = question_tokens(question)
      return semantic_table_bonus(table:, question:) if tokens.empty?

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

      token_score + semantic_table_bonus(table:, question:)
    end

    def resolve_data_source_candidate_from_state(state:)
      candidates = Array(state['candidate_data_sources'])
      matched_candidate = resolve_ordinal_candidate(candidates:) || candidates.find do |candidate|
        name = candidate['name'].to_s
        source_type = candidate['source_type'].to_s
        current_question.match?(candidate_name_regex(name)) ||
          current_question.match?(candidate_name_regex(source_type))
      end

      workspace.data_sources.find_by(id: matched_candidate['id']) if matched_candidate
    end

    def resolve_table_candidate_from_state(state:)
      candidates = Array(state['candidate_tables'])
      matched_candidate = resolve_ordinal_candidate(candidates:) || candidates.find do |candidate|
        qualified_name = candidate['qualified_name'].to_s
        name = candidate['name'].to_s
        current_question.match?(candidate_name_regex(qualified_name)) ||
          current_question.match?(candidate_name_regex(name))
      end

      matched_candidate&.dig('qualified_name')
    end

    def resolve_ordinal_candidate(candidates:)
      ORDINAL_HINTS.each do |regex, index|
        next unless current_question.match?(regex)

        return candidates[index]
      end

      nil
    end

    def schema_for(data_source)
      data_source.connector.list_tables(include_columns: true, selected_only: data_source.external_database?)
    end

    def compact_schema_for(data_source)
      data_source.connector.list_tables(include_columns: false, selected_only: data_source.external_database?)
    end

    def flatten_tables(schema)
      flattened_tables = Array(schema).flat_map do |group|
        Array(group[:tables] || group['tables'])
      end

      flattened_tables.map(&:stringify_keys)
    end

    def clarification_result(question:)
      executed(
        message: question,
        data: { 'clarification_required' => true }
      )
    end

    def data_source_clarification_message(candidates:)
      names = Array(candidates).map { |candidate| candidate['name'] || candidate[:name] }
      I18n.t('app.workspaces.chat.query.ask_data_source', data_sources: names.to_sentence)
    end

    def table_clarification_message(candidates:)
      names = Array(candidates).map { |candidate| candidate['qualified_name'] || candidate[:qualified_name] }
      I18n.t('app.workspaces.chat.query.ask_table', tables: names.to_sentence)
    end

    def schema_guidance_message(candidates:)
      names = Array(candidates).map { |candidate| candidate['qualified_name'] || candidate[:qualified_name] }
      I18n.t('app.workspaces.chat.query.schema_guidance', tables: names.to_sentence)
    end

    def formatted_query_result_message(data_source:, sql:, query_result:)
      row_count = query_result.rows.length
      lines = [
        I18n.t(
          'app.workspaces.chat.query.result_intro',
          data_source: data_source.display_name,
          row_count:
        ),
        "```sql\n#{sql}\n```"
      ]

      if row_count.zero?
        lines << I18n.t('app.workspaces.chat.query.no_rows')
        return lines.join("\n\n")
      end

      lines << markdown_table(columns: query_result.columns, rows: query_result.rows)
      lines.join("\n\n")
    end

    def markdown_table(columns:, rows:)
      visible_columns = Array(columns).first(8)
      visible_rows = Array(rows).first(20)

      header = "| #{visible_columns.join(' | ')} |"
      divider = "| #{visible_columns.map { '---' }.join(' | ')} |"
      body = visible_rows.map do |row|
        values = Array(row).first(visible_columns.length).map { |value| value.to_s.gsub('|', '\\|') }
        "| #{values.join(' | ')} |"
      end

      [header, divider, *body].join("\n")
    end

    def serialize_data_source(data_source:)
      data_source.safe_status_payload.transform_keys(&:to_s)
    end

    def question_tokens(question)
      question.to_s.downcase.scan(/[a-z][a-z0-9_]+/).reject { |token| STOPWORDS.include?(token) }.uniq
    end

    def schema_inference_request?
      current_question.match?(SCHEMA_INFERENCE_REGEX)
    end

    def semantic_table_bonus(table:, question:)
      lowered_question = question.to_s.downcase
      table_tokens = [
        table['name'].to_s.downcase,
        table['qualified_name'].to_s.downcase
      ]
      column_names = Array(table['columns']).map { |column| (column[:name] || column['name']).to_s.downcase }

      SEMANTIC_HINTS.sum do |keyword, hints|
        next 0 unless lowered_question.match?(/\b#{Regexp.escape(keyword)}s?\b/)

        bonus = 0
        bonus += 6 if table_tokens.any? { |name| hints[:tables].any? { |hint| name.include?(hint) } }
        bonus += 2 if column_names.any? { |column| hints[:columns].any? { |hint| column.include?(hint) } }
        bonus
      end
    end

    def new_query_request?
      current_question.match?(NEW_QUERY_SIGNAL_REGEX)
    end

    def table_matches_token?(qualified_name:, table_name:, token:)
      qualified_name.include?(token) ||
        table_name.include?(token.singularize) ||
        table_name.include?(token.pluralize)
    end

    def clarification_data_source_id(data_source_id:)
      data_source_id || payload['data_source_id'].presence || active_clarification_state['data_source_id']
    end

    def candidate_name_regex(name)
      /\b#{Regexp.escape(name)}\b/i
    end

    def clarification_store
      @clarification_store ||= if clarification_thread_id.present?
                                 QueryClarificationStateStore.new(
                                   workspace:,
                                   actor:,
                                   chat_thread_id: clarification_thread_id
                                 )
                               else
                                 NullClarificationStore.new
                               end
    end

    def clarification_thread_id
      payload['thread_id'].presence || payload[:thread_id]
    end

    def executed(message:, data: {})
      Result.new(status: 'executed', message:, data:, error_code: nil)
    end

    def validation_error(message, code: 'validation_error')
      Result.new(status: 'validation_error', message:, data: {}, error_code: code)
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
