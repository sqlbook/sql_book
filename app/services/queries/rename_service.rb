# frozen_string_literal: true

module Queries
  class RenameService
    Result = Struct.new(:success?, :query, :code, :fallback_message, keyword_init: true) do
      def message
        fallback_message
      end

      def error_code
        return code unless code.to_s.include?('.')

        _namespace, remainder = code.to_s.split('.', 2)
        remainder.to_s.tr('.', '_')
      end
    end

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call
      query = resolve_query
      return query if query.is_a?(Result)

      new_name = attributes['name'].to_s.strip
      if new_name.blank?
        return failure(code: 'query.rename_name_required',
                       fallback_message: 'Please provide a new query name.')
      end

      query.update!(name: new_name, saved: true, last_updated_by: actor)
      Result.new(success?: true, query:, code: 'query.renamed', fallback_message: nil)
    end

    private

    attr_reader :workspace, :actor, :attributes

    def resolve_query
      query_id = attributes['query_id'].to_i
      if query_id.zero?
        return failure(code: 'query.rename_query_required',
                       fallback_message: 'Please specify which saved query to rename.')
      end

      query_scope.find_by(id: query_id) || failure(code: 'query.not_found',
                                                   fallback_message: 'I could not find that saved query.')
    end

    def query_scope
      Query.joins(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
        .where(saved: true)
    end

    def failure(code:, fallback_message: nil)
      Result.new(success?: false, query: nil, code:, fallback_message:)
    end
  end
end
