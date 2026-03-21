# frozen_string_literal: true

module Queries
  class DeleteService
    Result = Struct.new(:success?, :deleted_query, :message, :error_code, keyword_init: true)

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call
      query = resolve_query
      return query if query.is_a?(Result)

      deleted_query = {
        'id' => query.id,
        'name' => query.name,
        'sql' => query.query,
        'data_source' => {
          'id' => query.data_source_id,
          'name' => query.data_source.display_name
        }
      }
      query.destroy!

      Result.new(success?: true, deleted_query:, message: nil, error_code: nil)
    end

    private

    attr_reader :workspace, :actor, :attributes

    def resolve_query
      query_id = attributes['query_id'].to_i
      return failure(message: I18n.t('app.workspaces.chat.query_library.delete_query_required')) if query_id.zero?

      query_scope.find_by(id: query_id) || failure(message: I18n.t('app.workspaces.chat.query_library.query_not_found'))
    end

    def query_scope
      Query.joins(:data_source)
        .includes(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
        .where(saved: true)
    end

    def failure(message:, code: 'validation_error')
      Result.new(success?: false, deleted_query: nil, message:, error_code: code)
    end
  end
end
