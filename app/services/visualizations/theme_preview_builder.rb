# frozen_string_literal: true

module Visualizations
  class ThemePreviewBuilder
    class << self
      def call(theme_json:)
        new(theme_json:).call
      end
    end

    def initialize(theme_json:)
      @theme_json = theme_json.to_h.deep_stringify_keys
    end

    def call
      {
        palette: Array(theme_json['color']).compact.first(6),
        charts: {
          'line' => line_option,
          'bar' => bar_option,
          'donut' => donut_option
        }
      }
    end

    private

    attr_reader :theme_json

    def line_option
      deep_compact(
        base_option(trigger: 'axis').merge(
          'dataset' => {
            'source' => [
              %w[quarter value],
              ['Q1', 120],
              ['Q2', 180],
              ['Q3', 150],
              ['Q4', 220]
            ]
          },
          'grid' => grid_option,
          'xAxis' => category_axis_option,
          'yAxis' => value_axis_option,
          'series' => [
            {
              'type' => 'line',
              'smooth' => true,
              'showSymbol' => false,
              'encode' => {
                'x' => 'quarter',
                'y' => 'value'
              }
            }
          ]
        )
      )
    end

    def bar_option
      deep_compact(
        base_option(trigger: 'axis').merge(
          'dataset' => {
            'source' => [
              %w[segment value],
              ['Search', 48],
              ['Product', 36],
              ['Expansion', 24],
              ['Churn', 12]
            ]
          },
          'grid' => grid_option,
          'xAxis' => value_axis_option,
          'yAxis' => category_axis_option,
          'series' => [
            {
              'type' => 'bar',
              'barMaxWidth' => 18,
              'encode' => {
                'x' => 'value',
                'y' => 'segment'
              }
            }
          ]
        )
      )
    end

    def donut_option
      deep_compact(
        base_option(trigger: 'item').merge(
          'dataset' => {
            'source' => [
              %w[segment value],
              ['Search', 46],
              ['Referral', 21],
              ['Partnership', 18],
              ['Other', 15]
            ]
          },
          'series' => [
            {
              'type' => 'pie',
              'radius' => ['52%', '72%'],
              'encode' => {
                'itemName' => 'segment',
                'value' => 'value'
              }
            }
          ]
        )
      )
    end

    def base_option(trigger:)
      {
        'backgroundColor' => theme_json['backgroundColor'],
        'color' => theme_json['color'],
        'textStyle' => theme_json['textStyle'],
        'animationDuration' => 0,
        'legend' => {
          'show' => false,
          'textStyle' => theme_json.dig('legend', 'textStyle')
        },
        'tooltip' => {
          'show' => true,
          'trigger' => trigger,
          'backgroundColor' => theme_json.dig('tooltip', 'backgroundColor'),
          'borderColor' => theme_json.dig('tooltip', 'borderColor'),
          'textStyle' => theme_json.dig('tooltip', 'textStyle')
        }
      }
    end

    def grid_option
      {
        'left' => 16,
        'right' => 16,
        'top' => 16,
        'bottom' => 16,
        'containLabel' => true
      }
    end

    def category_axis_option
      axis = theme_json.fetch('categoryAxis', {})

      {
        'type' => 'category',
        'axisLine' => axis['axisLine'],
        'axisLabel' => axis['axisLabel'],
        'splitLine' => axis['splitLine']
      }
    end

    def value_axis_option
      axis = theme_json.fetch('valueAxis', {})

      {
        'type' => 'value',
        'axisLine' => axis['axisLine'],
        'axisLabel' => axis['axisLabel'],
        'splitLine' => axis['splitLine']
      }
    end

    def deep_compact(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), memo|
          compacted = deep_compact(nested)
          next if compacted.nil? || compacted == {} || compacted == []

          memo[key] = compacted
        end
      when Array
        value.map { |nested| deep_compact(nested) }.compact
      else
        value
      end
    end
  end
end
