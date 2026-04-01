# frozen_string_literal: true

module Visualizations
  class OptionBuilder
    def initialize(query:, visualization:, mode:)
      @query = query
      @visualization = visualization
      @mode = mode.to_s == 'light' ? 'light' : 'dark'
    end

    def call
      return nil unless Visualizations::ChartRegistry.echarts?(visualization.chart_type)
      return nil if query.query_result.error

      option = base_option
      option.merge!(dataset_option)
      option.merge!(axes_option) if cartesian_chart?
      option['series'] = [series_option]
      option
    end

    private

    attr_reader :query, :visualization, :mode

    def theme
      @theme ||= ThemeResolver.resolve(
        workspace: query.data_source.workspace,
        theme_reference: visualization.theme_reference,
        mode:,
        appearance_overrides: visualization.appearance_config_for(mode:)
      )
    end

    def data_config
      @data_config ||= visualization.resolved_data_config(query_result: query.query_result)
    end

    def other_config
      @other_config ||= visualization.resolved_other_config(query_result: query.query_result)
    end

    def dataset_option
      {
        'dataset' => {
          'source' => [query.query_result.columns] + query.query_result.rows
        }
      }
    end

    def base_option
      option = {
        'backgroundColor' => theme['backgroundColor'],
        'color' => theme['color'],
        'textStyle' => theme['textStyle'],
        'animationDuration' => 250,
        'tooltip' => tooltip_option,
        'legend' => legend_option,
        'title' => title_option
      }

      option['grid'] = {
        'left' => 24,
        'right' => 24,
        'top' => title_spacing,
        'bottom' => 36,
        'containLabel' => true
      } if cartesian_chart?

      option
    end

    def tooltip_option
      {
        'show' => ActiveModel::Type::Boolean.new.cast(other_config['tooltip_enabled']),
        'trigger' => pie_like_chart? ? 'item' : 'axis',
        'backgroundColor' => theme.dig('tooltip', 'backgroundColor'),
        'borderColor' => theme.dig('tooltip', 'borderColor'),
        'textStyle' => theme.dig('tooltip', 'textStyle')
      }
    end

    def legend_option
      {
        'show' => ActiveModel::Type::Boolean.new.cast(other_config['legend_enabled']),
        'textStyle' => theme.dig('legend', 'textStyle')
      }
    end

    def title_option
      title = other_config['title'].to_s.strip
      subtitle = other_config['subtitle'].to_s.strip

      {
        'show' => ActiveModel::Type::Boolean.new.cast(other_config['title_enabled']) || \
          ActiveModel::Type::Boolean.new.cast(other_config['subtitle_enabled']),
        'text' => ActiveModel::Type::Boolean.new.cast(other_config['title_enabled']) ? title : '',
        'subtext' => ActiveModel::Type::Boolean.new.cast(other_config['subtitle_enabled']) ? subtitle : '',
        'left' => 'center',
        'textStyle' => theme.dig('title', 'textStyle'),
        'subtextStyle' => theme.dig('title', 'subtextStyle')
      }
    end

    def axes_option
      {
        'xAxis' => x_axis_option,
        'yAxis' => y_axis_option
      }
    end

    def x_axis_option
      axis_theme = horizontal_bar_chart? ? theme.fetch('valueAxis', {}) : theme.fetch('categoryAxis', {})

      {
        'type' => horizontal_bar_chart? ? 'value' : 'category',
        'name' => axis_name(
          enabled: other_config['x_axis_label_enabled'],
          label: other_config['x_axis_label']
        ),
        'nameLocation' => 'middle',
        'nameGap' => 28,
        'axisLine' => axis_theme['axisLine'],
        'axisLabel' => axis_theme['axisLabel'],
        'splitLine' => axis_theme['splitLine']
      }
    end

    def y_axis_option
      axis_theme = horizontal_bar_chart? ? theme.fetch('categoryAxis', {}) : theme.fetch('valueAxis', {})

      {
        'type' => horizontal_bar_chart? ? 'category' : 'value',
        'name' => axis_name(
          enabled: other_config['y_axis_label_enabled'],
          label: other_config['y_axis_label']
        ),
        'nameLocation' => 'middle',
        'nameGap' => horizontal_bar_chart? ? 52 : 48,
        'axisLine' => axis_theme['axisLine'],
        'axisLabel' => axis_theme['axisLabel'],
        'splitLine' => axis_theme['splitLine']
      }
    end

    def series_option
      return pie_series_option if pie_like_chart?

      {
        'type' => Visualizations::ChartRegistry.fetch(visualization.chart_type)[:echarts_series_type],
        'smooth' => %w[line area].include?(visualization.chart_type),
        'areaStyle' => visualization.chart_type == 'area' ? {} : nil,
        'encode' => cartesian_encode,
        'showSymbol' => visualization.chart_type != 'area'
      }.compact
    end

    def pie_series_option
      {
        'type' => 'pie',
        'radius' => visualization.chart_type == 'donut' ? [other_config['donut_inner_radius'] || '58%', '78%'] : '78%',
        'encode' => {
          'itemName' => data_config['dimension_key'],
          'value' => data_config['value_key']
        }
      }
    end

    def cartesian_encode
      if horizontal_bar_chart?
        {
          'x' => data_config['value_key'],
          'y' => data_config['dimension_key']
        }
      else
        {
          'x' => data_config['dimension_key'],
          'y' => data_config['value_key']
        }
      end
    end

    def cartesian_chart?
      Visualizations::ChartRegistry.cartesian?(visualization.chart_type)
    end

    def pie_like_chart?
      Visualizations::ChartRegistry.pie_like?(visualization.chart_type)
    end

    def horizontal_bar_chart?
      visualization.chart_type == 'bar'
    end

    def axis_name(enabled:, label:)
      return nil unless ActiveModel::Type::Boolean.new.cast(enabled)

      label.to_s.strip.presence
    end

    def title_spacing
      has_title = title_visible?
      has_subtitle = subtitle_visible?
      return 88 if has_title && has_subtitle
      return 64 if has_title || has_subtitle

      24
    end

    def title_visible?
      ActiveModel::Type::Boolean.new.cast(other_config['title_enabled']) || other_config['title'].to_s.strip.present?
    end

    def subtitle_visible?
      ActiveModel::Type::Boolean.new.cast(other_config['subtitle_enabled']) || other_config['subtitle'].to_s.strip.present?
    end
  end
end
