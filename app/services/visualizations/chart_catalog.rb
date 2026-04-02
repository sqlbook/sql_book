# frozen_string_literal: true

module Visualizations
  module ChartCatalog # rubocop:disable Metrics/ModuleLength
    ALL_TYPES = {
      'total' => {
        icon: 'ri-hashtag',
        asset_name: 'total.svg',
        label_key: 'app.workspaces.visualizations.types.total.label',
        description_key: 'app.workspaces.visualizations.types.total.description',
        renderer: 'total',
        enabled: true
      },
      'table' => {
        icon: 'ri-table-2',
        asset_name: 'table.svg',
        label_key: 'app.workspaces.visualizations.types.table.label',
        description_key: 'app.workspaces.visualizations.types.table.description',
        renderer: 'table',
        enabled: true
      },
      'line' => {
        icon: 'ri-line-chart-line',
        asset_name: 'line.svg',
        label_key: 'app.workspaces.visualizations.types.line.label',
        description_key: 'app.workspaces.visualizations.types.line.description',
        renderer: 'echarts',
        echarts_series_type: 'line',
        enabled: true
      },
      'area' => {
        icon: 'ri-area-chart-line',
        asset_name: 'area.svg',
        label_key: 'app.workspaces.visualizations.types.area.label',
        description_key: 'app.workspaces.visualizations.types.area.description',
        renderer: 'echarts',
        echarts_series_type: 'line',
        enabled: true
      },
      'stacked_area' => {
        icon: 'ri-area-chart-line',
        asset_name: 'stacked-area.svg',
        label_key: 'app.workspaces.visualizations.types.stacked_area.label',
        description_key: 'app.workspaces.visualizations.types.stacked_area.description',
        renderer: 'echarts',
        echarts_series_type: 'line',
        enabled: false
      },
      'column' => {
        icon: 'ri-bar-chart-box-line',
        asset_name: 'column.svg',
        label_key: 'app.workspaces.visualizations.types.column.label',
        description_key: 'app.workspaces.visualizations.types.column.description',
        renderer: 'echarts',
        echarts_series_type: 'bar',
        enabled: true
      },
      'stacked_column' => {
        icon: 'ri-bar-chart-box-line',
        asset_name: 'stacked-column.svg',
        label_key: 'app.workspaces.visualizations.types.stacked_column.label',
        description_key: 'app.workspaces.visualizations.types.stacked_column.description',
        renderer: 'echarts',
        echarts_series_type: 'bar',
        enabled: false
      },
      'bar' => {
        icon: 'ri-bar-chart-horizontal-line',
        asset_name: 'bar.svg',
        label_key: 'app.workspaces.visualizations.types.bar.label',
        description_key: 'app.workspaces.visualizations.types.bar.description',
        renderer: 'echarts',
        echarts_series_type: 'bar',
        enabled: true
      },
      'stacked_bar' => {
        icon: 'ri-bar-chart-horizontal-line',
        asset_name: 'stacked-bar.svg',
        label_key: 'app.workspaces.visualizations.types.stacked_bar.label',
        description_key: 'app.workspaces.visualizations.types.stacked_bar.description',
        renderer: 'echarts',
        echarts_series_type: 'bar',
        enabled: false
      },
      'combo' => {
        icon: 'ri-line-chart-line',
        asset_name: 'combo.svg',
        label_key: 'app.workspaces.visualizations.types.combo.label',
        description_key: 'app.workspaces.visualizations.types.combo.description',
        renderer: 'echarts',
        enabled: false
      },
      'pie' => {
        icon: 'ri-pie-chart-2-line',
        asset_name: 'pie.svg',
        label_key: 'app.workspaces.visualizations.types.pie.label',
        description_key: 'app.workspaces.visualizations.types.pie.description',
        renderer: 'echarts',
        echarts_series_type: 'pie',
        enabled: true
      },
      'donut' => {
        icon: 'ri-donut-chart-line',
        asset_name: 'donut.svg',
        label_key: 'app.workspaces.visualizations.types.donut.label',
        description_key: 'app.workspaces.visualizations.types.donut.description',
        renderer: 'echarts',
        echarts_series_type: 'pie',
        enabled: true
      }
    }.freeze
  end # rubocop:enable Metrics/ModuleLength
end
