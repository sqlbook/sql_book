# frozen_string_literal: true

module Visualizations
  class SystemTheme
    REFERENCE_KEY = 'system.default_theming'

    attr_reader :workspace

    def initialize(workspace:)
      @workspace = workspace
    end

    def id
      REFERENCE_KEY
    end

    def name
      I18n.t('app.workspaces.settings.branding.system_theme_name')
    end

    def reference_key
      REFERENCE_KEY
    end

    def default?
      workspace.default_visualization_theme.blank?
    end

    def read_only?
      true
    end

    def system_theme?
      true
    end

    def theme_json_dark
      ThemeTokens.resolve(ThemeTokens.default_theme, mode: :dark)
    end

    def theme_json_light
      ThemeTokens.resolve(ThemeTokens.default_theme, mode: :light)
    end
  end
end
