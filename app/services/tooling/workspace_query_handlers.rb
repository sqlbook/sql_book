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

      Result.new(status: 'executed', message: list_message(payload:), data: { 'queries' => payload }, error_code: nil)
    end

    def run(arguments:)
      result = Queries::RunService.new(workspace:, actor:, payload: arguments).call
      Result.new(
        status: result.status,
        message: result.message,
        data: result.data,
        error_code: result.error_code
      )
    end

    def save(arguments:)
      result = Queries::SaveService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          message: result.message,
          data: {},
          error_code: result.error_code
        )
      end

      query = result.query
      Result.new(
        status: 'executed',
        message: I18n.t('app.workspaces.chat.query_library.saved', name: query.name),
        data: {
          'query' => serialize_query(query:)
        },
        error_code: nil
      )
    end

    def rename(arguments:)
      result = Queries::RenameService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          message: result.message,
          data: {},
          error_code: result.error_code
        )
      end

      query = result.query
      Result.new(
        status: 'executed',
        message: I18n.t('app.workspaces.chat.query_library.renamed', name: query.name),
        data: {
          'query' => serialize_query(query:)
        },
        error_code: nil
      )
    end

    def delete(arguments:)
      result = Queries::DeleteService.new(workspace:, actor:, attributes: arguments).call
      unless result.success?
        return Result.new(
          status: 'validation_error',
          message: result.message,
          data: {},
          error_code: result.error_code
        )
      end

      Result.new(
        status: 'executed',
        message: I18n.t('app.workspaces.chat.query_library.deleted', name: result.deleted_query['name']),
        data: {
          'deleted_query' => result.deleted_query
        },
        error_code: nil
      )
    end

    private

    attr_reader :workspace, :actor

    def list_message(payload:)
      return I18n.t('app.workspaces.chat.query_library.none') if payload.empty?

      [
        I18n.t('app.workspaces.chat.query_library.found', count: payload.size),
        payload.map { |query| query_library_item_text(query:) }.join("\n")
      ].join("\n\n")
    end

    def query_library_item_text(query:)
      I18n.t(
        'app.workspaces.chat.query_library.item',
        name: query['name'],
        data_source: query.dig('data_source', 'name')
      )
    end

    def serialize_query(query:)
      {
        'id' => query.id,
        'name' => query.name,
        'sql' => query.query,
        'saved' => query.saved,
        'chart_type' => query.chart_type,
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
  end
end
