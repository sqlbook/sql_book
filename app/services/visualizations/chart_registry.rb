# frozen_string_literal: true

module Visualizations
  module ChartRegistry
    module_function

    TYPES = {
      'table' => {
        icon: 'ri-table-2',
        label_key: 'app.workspaces.visualizations.types.table.label',
        description_key: 'app.workspaces.visualizations.types.table.description',
        renderer: 'table'
      },
      'total' => {
        icon: 'ri-hashtag',
        label_key: 'app.workspaces.visualizations.types.total.label',
        description_key: 'app.workspaces.visualizations.types.total.description',
        renderer: 'total'
      },
      'line' => {
        icon: 'ri-line-chart-line',
        label_key: 'app.workspaces.visualizations.types.line.label',
        description_key: 'app.workspaces.visualizations.types.line.description',
        renderer: 'echarts',
        echarts_series_type: 'line'
      },
      'area' => {
        icon: 'ri-area-chart-line',
        label_key: 'app.workspaces.visualizations.types.area.label',
        description_key: 'app.workspaces.visualizations.types.area.description',
        renderer: 'echarts',
        echarts_series_type: 'line'
      },
      'column' => {
        icon: 'ri-bar-chart-box-line',
        label_key: 'app.workspaces.visualizations.types.column.label',
        description_key: 'app.workspaces.visualizations.types.column.description',
        renderer: 'echarts',
        echarts_series_type: 'bar'
      },
      'bar' => {
        icon: 'ri-bar-chart-horizontal-line',
        label_key: 'app.workspaces.visualizations.types.bar.label',
        description_key: 'app.workspaces.visualizations.types.bar.description',
        renderer: 'echarts',
        echarts_series_type: 'bar'
      },
      'pie' => {
        icon: 'ri-pie-chart-2-line',
        label_key: 'app.workspaces.visualizations.types.pie.label',
        description_key: 'app.workspaces.visualizations.types.pie.description',
        renderer: 'echarts',
        echarts_series_type: 'pie'
      },
      'donut' => {
        icon: 'ri-donut-chart-line',
        label_key: 'app.workspaces.visualizations.types.donut.label',
        description_key: 'app.workspaces.visualizations.types.donut.description',
        renderer: 'echarts',
        echarts_series_type: 'pie'
      }
    }.freeze

    def types
      TYPES.keys
    end

    def fetch(chart_type)
      TYPES.fetch(chart_type.to_s)
    end

    def available
      TYPES.map do |chart_type, config|
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
