# frozen_string_literal: true

module Visualizations
  module Defaults
    module_function

    DEFAULT_TABLE_PAGE_SIZE = 10
    DEFAULT_DONUT_INNER_RADIUS = '58%'

    def data_config(chart_type:, columns:)
      first = columns.first
      second = columns.second || first
      last = columns.last || second || first

      {
        'dimension_key' => first,
        'value_key' => last,
        'table_page_size' => DEFAULT_TABLE_PAGE_SIZE
      }.merge(type_specific_data(chart_type:, first:, second:, last:))
    end

    def other_config(chart_type:, columns:)
      first = columns.first
      last = columns.last || first

      {
        'title' => nil,
        'subtitle' => nil,
        'title_enabled' => false,
        'subtitle_enabled' => false,
        'legend_enabled' => legend_enabled_default(chart_type),
        'tooltip_enabled' => true,
        'x_axis_label' => first&.humanize,
        'x_axis_label_enabled' => Visualizations::ChartRegistry.cartesian?(chart_type),
        'y_axis_label' => last&.humanize,
        'y_axis_label_enabled' => Visualizations::ChartRegistry.cartesian?(chart_type),
        'total_label' => nil,
        'total_label_enabled' => false,
        'donut_inner_radius' => DEFAULT_DONUT_INNER_RADIUS
      }
    end

    def appearance_config
      {}
    end

    def legend_enabled_default(chart_type)
      Visualizations::ChartRegistry.pie_like?(chart_type)
    end

    def type_specific_data(chart_type:, first:, second:, last:)
      case chart_type.to_s
      when 'pie', 'donut'
        {
          'dimension_key' => first,
          'value_key' => second || last || first
        }
      when 'total'
        {
          'value_key' => first
        }
      else
        {}
      end
    end
  end
end
