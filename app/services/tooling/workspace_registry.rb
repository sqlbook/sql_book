# frozen_string_literal: true

module Tooling
  module WorkspaceRegistry
    module_function

    def tool_metadata
      WorkspaceTeamRegistry.tool_metadata +
        WorkspaceChatThreadRegistry.tool_metadata +
        WorkspaceDataSourceRegistry.tool_metadata +
        WorkspaceQueryRegistry.tool_metadata
    end

    def definitions(handlers:)
      team_handlers = handlers.fetch(:team)
      chat_thread_handlers = handlers.fetch(:chat_threads)
      data_source_handlers = handlers.fetch(:data_sources)
      query_handlers = handlers.fetch(:queries)

      WorkspaceTeamRegistry.definitions(handlers: team_handlers) +
        WorkspaceChatThreadRegistry.definitions(handlers: chat_thread_handlers) +
        WorkspaceDataSourceRegistry.definitions(handlers: data_source_handlers) +
        WorkspaceQueryRegistry.definitions(handlers: query_handlers)
    end
  end
end
