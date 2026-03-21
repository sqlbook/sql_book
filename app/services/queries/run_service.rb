# frozen_string_literal: true

module Queries
  class RunService
    def initialize(workspace:, actor:, payload:)
      @workspace = workspace
      @actor = actor
      @payload = payload
    end

    def call
      Chat::DataSourceQueryService.new(workspace:, actor:, payload:).call
    end

    private

    attr_reader :workspace, :actor, :payload
  end
end
