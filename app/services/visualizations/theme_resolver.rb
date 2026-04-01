# frozen_string_literal: true

module Visualizations
  class ThemeResolver
    class << self
      def resolve(workspace:, theme_reference:, mode:, appearance_overrides: {})
        new(workspace:, theme_reference:, mode:, appearance_overrides:).resolve
      end
    end

    def initialize(workspace:, theme_reference:, mode:, appearance_overrides: {})
      @workspace = workspace
      @theme_reference = theme_reference
      @mode = mode.to_s == 'light' ? 'light' : 'dark'
      @appearance_overrides = appearance_overrides.to_h.deep_stringify_keys
    end

    def resolve
      resolved_theme.deep_merge(appearance_overrides)
    end

    private

    attr_reader :workspace, :theme_reference, :mode, :appearance_overrides

    def resolved_theme
      theme = ThemeLibraryService.find_entry(workspace:, reference: theme_reference)

      case theme
      when SystemTheme
        mode == 'light' ? theme.theme_json_light : theme.theme_json_dark
      when VisualizationTheme
        mode == 'light' ? theme.theme_json_light : theme.theme_json_dark
      else
        {}
      end.to_h.deep_stringify_keys
    end
  end
end
