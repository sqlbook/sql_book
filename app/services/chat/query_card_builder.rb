# frozen_string_literal: true

module Chat
  class QueryCardBuilder # rubocop:disable Metrics/ClassLength
    def initialize(workspace:, execution_data:, intent_payload:)
      @workspace = workspace
      @execution_data = execution_data.to_h.deep_stringify_keys
      @intent_payload = intent_payload.to_h.deep_stringify_keys
    end

    def call
      return {} if sql.blank?

      data_source = resolved_data_source
      return {} unless data_source

      base_payload(data_source:).merge(schema_payload(data_source:)).compact
    end

    def summary_message
      return '' unless resolved_data_source

      I18n.t(summary_message_key, **summary_message_arguments)
    end

    private

    attr_reader :workspace, :execution_data, :intent_payload

    def sql
      @sql ||= execution_data['sql'].to_s.strip
    end

    def question
      execution_data['question'].to_s.strip.presence
    end

    def row_count
      execution_data['row_count'].to_i
    end

    def summary_message_key
      return 'app.workspaces.chat.query.result_intro_refined' if refined_or_updated_query?

      'app.workspaces.chat.query.result_intro'
    end

    def summary_message_arguments
      arguments = { row_count: }
      return arguments if refined_or_updated_query?

      arguments.merge(
        data_source: execution_data.dig('data_source', 'name').presence || resolved_data_source.display_name
      )
    end

    def columns
      Array(execution_data['columns']).map(&:to_s)
    end

    def rows
      Array(execution_data['rows'])
    end

    def resolved_data_source
      @resolved_data_source ||= workspace.data_sources.find_by(id: execution_data.dig('data_source', 'id'))
    end

    def refined_or_updated_query?
      intent_payload['base_sql'].to_s.strip.present? || intent_payload['query_id'].to_s.strip.present?
    end

    def base_saved_query
      @base_saved_query ||= find_base_saved_query
    end

    def saved_query
      @saved_query ||= query_payload_from_execution_data
    end

    def card_state
      return 'saved' if saved_query.present?
      return 'refinement' if base_saved_query.present?

      'unsaved'
    end

    def suggested_name(data_source:)
      Queries::NameGenerator.generate(
        question: question,
        sql:,
        data_source:
      )
    end

    def serialized_query(query)
      return if query.blank?

      {
        'id' => query.id,
        'name' => query.name,
        'data_source_id' => query.data_source_id,
        'data_source_name' => query.data_source.display_name,
        'sql' => query.query
      }
    end

    def serialized_data_source(data_source)
      {
        'id' => data_source.id,
        'name' => execution_data.dig('data_source', 'name').presence || data_source.display_name
      }
    end

    def find_base_saved_query
      query_id = intent_payload['base_saved_query_id'].to_i
      return if query_id.zero?

      Query.joins(:data_source)
        .find_by(id: query_id, data_sources: { workspace_id: workspace.id })
    end

    def base_payload(data_source:)
      {
        'state' => card_state,
        'question' => question,
        'sql' => sql,
        'row_count' => row_count,
        'columns' => columns,
        'rows' => rows,
        'suggested_name' => suggested_name(data_source:),
        'saved_query' => saved_query,
        'data_source' => serialized_data_source(data_source),
        'base_saved_query' => serialized_query(base_saved_query)
      }
    end

    def schema_payload(data_source:)
      QueryCardSchemaBuilder.new(data_source:).call
    end

    def query_payload_from_execution_data
      payload = execution_data['query'].to_h.deep_stringify_keys
      return if payload.blank? || payload['id'].blank?

      {
        'id' => payload['id'],
        'name' => payload['name'],
        'data_source_id' => payload.dig('data_source', 'id') || payload['data_source_id'],
        'data_source_name' => payload.dig('data_source', 'name') || payload['data_source_name'],
        'sql' => payload['sql']
      }.compact
    end
  end
end
