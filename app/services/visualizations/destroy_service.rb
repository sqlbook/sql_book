# frozen_string_literal: true

module Visualizations
  class DestroyService
    Result = Struct.new(:success?, :code, :message, keyword_init: true)

    def initialize(query:, chart_type:)
      @query = query
      @chart_type = chart_type.to_s.strip
    end

    def call
      query.visualizations.find_by(chart_type:)&.destroy!
      Result.new(success?: true, code: 'visualization.deleted', message: nil)
    end

    private

    attr_reader :query, :chart_type
  end
end
