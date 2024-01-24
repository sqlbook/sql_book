# frozen_string_literal: true

module App
  module Workspaces
    module QueriesHelper
      def chart_types
        [
          {
            key: 'total',
            label_tag: :chart_type_total,
            image: 'charts/total.svg',
            label: 'Total'
          },
          {
            key: 'table',
            label_tag: :chart_type_table,
            image: 'charts/table.svg',
            label: 'Table'
          },
          {
            key: 'line',
            label_tag: :chart_type_line,
            image: 'charts/line.svg',
            label: 'Line'
          },
          {
            key: 'area',
            label_tag: :chart_type_area,
            image: 'charts/area.svg',
            label: 'Area'
          },
          {
            key: 'stacked_area',
            label_tag: :chart_type_stacked_area,
            image: 'charts/stacked-area.svg',
            label: 'Stacked area'
          },
          {
            key: 'Column',
            label_tag: :chart_type_column,
            image: 'charts/column.svg',
            label: 'Column'
          },
          {
            key: 'stacked_column',
            label_tag: :chart_type_stacked_column,
            image: 'charts/stacked-column.svg',
            label: 'Stacked column'
          },
          {
            key: 'Bar',
            label_tag: :chart_type_bar,
            image: 'charts/bar.svg',
            label: 'Bar'
          },
          {
            key: 'Stacked bar',
            label_tag: :chart_type_stacked_bar,
            image: 'charts/stacked-bar.svg',
            label: 'Stacked bar'
          },
          {
            key: 'combo',
            label_tag: :chart_type_combo,
            image: 'charts/combo.svg',
            label: 'Combo'
          },
          {
            key: 'pie',
            label_tag: :chart_type_pie,
            image: 'charts/pie.svg',
            label: 'Pie'
          },
          {
            key: 'donut',
            label_tag: :chart_type_donut,
            image: 'charts/donut.svg',
            label: 'Donut'
          }
        ]
      end
    end
  end
end
