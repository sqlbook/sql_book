# frozen_string_literal: true

module Tooling
  module WorkspaceRegistry
    module_function

    def tool_metadata
      WorkspaceTeamRegistry.tool_metadata + WorkspaceDataSourceRegistry.tool_metadata
    end

    def definitions(handlers:)
      team_handlers = handlers.fetch(:team)
      data_source_handlers = handlers.fetch(:data_sources)

      WorkspaceTeamRegistry.definitions(handlers: team_handlers) +
        WorkspaceDataSourceRegistry.definitions(handlers: data_source_handlers)
    end
  end
end
