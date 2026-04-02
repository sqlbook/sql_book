# frozen_string_literal: true

module Visualizations
  module ChartRegistry
    module_function

    ALL_TYPES = ChartCatalog::ALL_TYPES

    ACTIVE_TYPES = ALL_TYPES.select { |_chart_type, config| config[:enabled] }.freeze

    def types
      ACTIVE_TYPES.keys
    end

    def fetch(chart_type)
      ACTIVE_TYPES.fetch(chart_type.to_s)
    end

    def available
      ALL_TYPES.map do |chart_type, config|
        config.merge(chart_type:)
      end
    end

    def echarts?(chart_type)
      fetch(chart_type)[:renderer] == 'echarts'
    end

    def cartesian?(chart_type)
      %w[line area column bar].include?(chart_type.to_s)
    end

    def pie_like?(chart_type)
      %w[pie donut].include?(chart_type.to_s)
    end
  end
end
