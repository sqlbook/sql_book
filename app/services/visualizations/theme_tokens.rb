# frozen_string_literal: true

module Visualizations
  module ThemeTokens # rubocop:disable Metrics/ModuleLength
    module_function

    DEFAULT_THEME = {
      'color' => [
        'token:accent.1',
        'token:accent.2',
        'token:accent.3',
        'token:accent.4',
        'token:accent.5',
        'token:accent.6'
      ],
      'backgroundColor' => 'token:surface.canvas',
      'textStyle' => {
        'color' => 'token:text.primary'
      },
      'title' => {
        'textStyle' => {
          'color' => 'token:text.primary',
          'fontWeight' => 700
        },
        'subtextStyle' => {
          'color' => 'token:text.muted'
        }
      },
      'legend' => {
        'textStyle' => {
          'color' => 'token:text.secondary'
        }
      },
      'tooltip' => {
        'backgroundColor' => 'token:surface.panel',
        'borderColor' => 'token:border.strong',
        'textStyle' => {
          'color' => 'token:text.primary'
        }
      },
      'categoryAxis' => {
        'axisLine' => {
          'lineStyle' => {
            'color' => 'token:border.strong'
          }
        },
        'axisLabel' => {
          'color' => 'token:text.secondary'
        },
        'splitLine' => {
          'lineStyle' => {
            'color' => 'token:border.subtle'
          }
        }
      },
      'valueAxis' => {
        'axisLine' => {
          'lineStyle' => {
            'color' => 'token:border.strong'
          }
        },
        'axisLabel' => {
          'color' => 'token:text.secondary'
        },
        'splitLine' => {
          'lineStyle' => {
            'color' => 'token:border.subtle'
          }
        }
      }
    }.freeze

    DARK_COLORS = {
      'accent.1' => '#F5807B',
      'accent.2' => '#5CA1F2',
      'accent.3' => '#F8BD77',
      'accent.4' => '#D97FC6',
      'accent.5' => '#6CCB5F',
      'accent.6' => '#F0E15A',
      'surface.canvas' => '#1C1C1C',
      'surface.panel' => '#222222',
      'text.primary' => '#ECEAE6',
      'text.secondary' => '#BBBBBB',
      'text.muted' => '#A1A1A1',
      'border.strong' => '#505050',
      'border.subtle' => '#333333'
    }.freeze

    LIGHT_COLORS = {
      'accent.1' => '#FF6A64',
      'accent.2' => '#3E86D9',
      'accent.3' => '#D88B39',
      'accent.4' => '#B2405B',
      'accent.5' => '#4FAE42',
      'accent.6' => '#C3B03A',
      'surface.canvas' => '#F4F2EE',
      'surface.panel' => '#FAF9F7',
      'text.primary' => '#111111',
      'text.secondary' => '#333333',
      'text.muted' => '#505050',
      'border.strong' => '#A1A1A1',
      'border.subtle' => '#CCCCCC'
    }.freeze

    def default_theme
      DEFAULT_THEME.deep_dup
    end

    def resolve(payload, mode:)
      palette = mode.to_s == 'light' ? LIGHT_COLORS : DARK_COLORS
      resolve_value(payload, palette:)
    end

    def token?(value)
      value.to_s.start_with?('token:')
    end

    def resolve_value(value, palette:)
      return value.to_h.transform_values { |nested| resolve_value(nested, palette:) } if value.is_a?(Hash)
      return value.map { |nested| resolve_value(nested, palette:) } if value.is_a?(Array)
      return resolve_token(value, palette:) if value.is_a?(String)

      value
    end

    def resolve_token(value, palette:)
      return value unless token?(value)

      palette.fetch(value.delete_prefix('token:'), value)
    end
  end
end
