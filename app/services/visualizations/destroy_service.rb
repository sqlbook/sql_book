# frozen_string_literal: true

module Visualizations
  class DestroyService
    Result = Struct.new(:success?, :code, :message, keyword_init: true)

    def initialize(query:)
      @query = query
    end

    def call
      query.visualization&.destroy!
      Result.new(success?: true, code: 'visualization.deleted', message: nil)
    end

    private

    attr_reader :query
  end
end
