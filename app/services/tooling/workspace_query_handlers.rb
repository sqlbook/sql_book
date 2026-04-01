# frozen_string_literal: true

module Tooling
  class WorkspaceQueryHandlers # rubocop:disable Metrics/ClassLength
    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    def list(arguments:)
      queries = Queries::LibraryService.new(workspace:, filters: arguments).call
      payload = queries.map { |query| serialize_query(query:) }

      Result.new(
        status: 'executed',
        code: 'query.listed',
        data: { 'queries' => payload, 'count' => payload.size },
        fallback_message: list_fallback(payload:)
      )
    end

    def run(arguments:)
      result = Queries::RunService.new(workspace:, actor:, payload: arguments).call
      Result.new(
        status: result.status,
        code: result.code,
        data: result.data,
        fallback_message: result.fallback_message
      )
    end

    def save(arguments:)
      result = Queries::SaveService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          code: result.code,
          data: save_failure_data(result:),
          fallback_message: result.fallback_message
        )
      end

      query = result.query
      Result.new(
        status: 'executed',
        code: result.code,
        data: {
          'query' => serialize_query(query:),
          'save_outcome' => result.save_outcome
        },
        fallback_message: query_save_fallback(result:)
      )
    end

    def rename(arguments:)
      result = Queries::RenameService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          code: result.code,
          data: {},
          fallback_message: result.fallback_message
        )
      end

      query = result.query
      Result.new(
        status: 'executed',
        code: result.code,
        data: { 'query' => serialize_query(query:) },
        fallback_message: "Renamed the saved query to #{query.name}."
      )
    end

    def update(arguments:) # rubocop:disable Metrics/AbcSize
      result = Queries::UpdateService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          code: result.code,
          data: update_failure_data(result:),
          fallback_message: result.fallback_message
        )
      end

      query = result.query
      query_run_data = query_result_data_for_update(query:, arguments:)
      Result.new(
        status: 'executed',
        code: result.code,
        data: {
          'query' => serialize_query(query:),
          'update_outcome' => result.update_outcome
        }.merge(query_run_data).merge(query_name_review_data(query:, arguments:)),
        fallback_message: query_update_fallback(result:)
      )
    end

    def delete(arguments:)
      result = Queries::DeleteService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          code: result.code,
          data: {},
          fallback_message: result.fallback_message
        )
      end

      Result.new(
        status: 'executed',
        code: result.code,
        data: { 'deleted_query' => result.deleted_query },
        fallback_message: "Deleted the saved query #{result.deleted_query['name']}."
      )
    end

    private

    attr_reader :workspace, :actor

    def list_fallback(payload:)
      return 'There are no saved queries in this workspace yet.' if payload.empty?

      lines = payload.map do |query|
        source_name = query.dig('data_source', 'name')
        source_name.present? ? "#{query['name']} (#{source_name})" : query['name']
      end

      ["Found #{payload.size} saved quer#{payload.size == 1 ? 'y' : 'ies'}.", lines.join("\n")].join("\n\n")
    end

    def serialize_query(query:)
      visualizations = query.visualizations.order(:chart_type).to_a

      {
        'id' => query.id,
        'name' => query.name,
        'sql' => query.query,
        'saved' => query.saved,
        'visualization_types' => visualizations.map(&:chart_type),
        'visualizations' => visualizations.map do |visualization|
          Visualizations::Serializer.call(
            query:,
            visualization:,
            include_preview: false
          )
        end,
        'data_source' => serialize_data_source(query:),
        'author' => serialize_author(query:),
        'chat_source' => serialize_chat_source(query:),
        'updated_at' => query.updated_at&.iso8601
      }.compact
    end

    def serialize_data_source(query:)
      {
        'id' => query.data_source_id,
        'name' => query.data_source.display_name
      }
    end

    def serialize_author(query:)
      {
        'id' => query.author_id,
        'name' => query.author&.full_name.to_s.presence || query.author&.email.to_s,
        'email' => query.author&.email.to_s
      }
    end

    def serialize_chat_source(query:)
      Queries::ChatSourceResolver.new(query:, viewer: actor, workspace:).call
    end

    def query_save_fallback(result:)
      name = result.query.name
      return "That SQL is already saved as #{name}." if result.save_outcome == 'already_saved'

      "Saved the query as #{name}."
    end

    def query_update_fallback(result:)
      query = result.query
      case result.update_outcome
      when 'already_saved'
        "That SQL is already saved as #{query.name}."
      when 'unchanged'
        "#{query.name} is already up to date."
      else
        "Updated the saved query #{query.name}."
      end
    end

    def update_failure_data(result:)
      return {} unless result.code == 'query.duplicate_saved_query' && result.conflicting_query.present?

      {
        'conflicting_query' => serialize_query(query: result.conflicting_query)
      }
    end

    def save_failure_data(result:)
      return {} unless result.code == 'query.generated_name_conflict' && result.conflicting_query.present?

      {
        'proposed_name' => result.proposed_name,
        'conflicting_query' => serialize_query(query: result.conflicting_query)
      }.compact
    end

    def query_result_data_for_update(query:, arguments:)
      return {} unless sql_update_requested?(arguments:)

      query_result = execute_query_update_result(query:)
      return {} unless query_result

      serialize_query_result(query:, query_result:)
    end

    def query_name_review_data(query:, arguments:) # rubocop:disable Metrics/AbcSize
      return {} unless sql_update_requested?(arguments:)
      return {} if arguments.to_h.deep_stringify_keys['name'].to_s.strip.present?

      review = name_review_for_updated_query(query:, arguments:)
      return {} if review.blank?

      payload = {
        'name_review' => {
          'status' => review.status,
          'current_name' => query.name
        }
      }

      return payload if review.status != 'stale' || review.suggested_name.blank?

      payload['name_review']['suggested_name'] = review.suggested_name
      payload.merge(
        'name_status' => review.status,
        'current_name' => query.name,
        'suggested_name' => review.suggested_name,
        'next_actions' => [
          {
            'action_type' => 'query.rename',
            'label' => 'rename the saved query',
            'arguments' => {
              'query_id' => query.id,
              'name' => review.suggested_name
            }
          }
        ],
        'follow_up' => {
          'kind' => 'query_rename_suggestion',
          'domain' => 'query',
          'target_type' => 'saved_query',
          'target_id' => query.id,
          'payload' => {
            'current_name' => query.name,
            'suggested_name' => review.suggested_name,
            'prompt_summary' => %(Consider renaming "#{query.name}" to "#{review.suggested_name}")
          }
        }
      )
    end

    def name_review_for_updated_query(query:, arguments:)
      payload = arguments.to_h.deep_stringify_keys

      Queries::NameReviewService.review(
        current_name: query.name,
        question: payload['question'],
        sql: query.query,
        data_source: query.data_source,
        actor:
      )
    rescue Queries::GeneratedNameService::ConfigurationError,
           Queries::GeneratedNameService::RequestError => e
      Rails.logger.warn(
        "WorkspaceQueryHandlers#update name review failed for Query##{query.id}: " \
        "#{e.class} #{e.message}"
      )
      Queries::NameReviewResponseParser::Result.new(status: 'uncertain', suggested_name: nil, reason: e.message)
    end

    def sql_update_requested?(arguments:)
      arguments.to_h.deep_stringify_keys['sql'].to_s.strip.present?
    end

    def execute_query_update_result(query:)
      query.data_source.connector.execute_readonly(sql: query.query)
    rescue DataSources::Connectors::BaseConnector::ConnectionError,
           DataSources::Connectors::BaseConnector::QueryError => e
      log_update_query_result_failure(query:, error: e)
      nil
    end

    def serialize_query_result(query:, query_result:)
      {
        'question' => query.name,
        'sql' => query.query,
        'data_source' => serialize_data_source(query:),
        'columns' => query_result.columns,
        'rows' => query_result.rows,
        'row_count' => query_result.rows.length
      }
    end

    def log_update_query_result_failure(query:, error:)
      Rails.logger.warn(
        "WorkspaceQueryHandlers#update result query failed for Query##{query.id}: " \
        "#{error.class} #{error.message}"
      )
    end
  end
end
