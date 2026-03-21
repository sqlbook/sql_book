# frozen_string_literal: true

module Queries
  class LibraryService
    def initialize(workspace:, filters: {})
      @workspace = workspace
      @filters = filters.to_h.deep_stringify_keys
    end

    def call
      scoped_queries
        .includes(:data_source, :author, :last_updated_by, { chat_query_references: :chat_thread })
        .order(updated_at: :desc, id: :desc)
    end

    private

    attr_reader :workspace, :filters

    def scoped_queries
      filter_by_search(
        filter_by_data_source(
          Query.joins(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
            .where(saved: true)
        )
      )
    end

    def filter_by_data_source(relation)
      return relation if filters['data_source_id'].blank?

      relation.where(data_source_id: filters['data_source_id'].to_i)
    end

    def filter_by_search(relation)
      return relation if filters['search'].blank?

      relation.where('LOWER(queries.name) LIKE ?', "%#{filters['search'].to_s.downcase}%")
    end
  end
end
