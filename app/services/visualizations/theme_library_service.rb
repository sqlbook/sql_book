# frozen_string_literal: true

module Visualizations
  class ThemeLibraryService
    class << self
      def call(workspace:)
        new(workspace:).call
      end

      def find_entry(workspace:, reference:)
        new(workspace:).find_entry(reference:)
      end
    end

    def initialize(workspace:)
      @workspace = workspace
    end

    def call
      [system_theme] + workspace.visualization_themes.ordered.to_a
    end

    def find_entry(reference:)
      return system_theme if reference.to_s == SystemTheme::REFERENCE_KEY

      workspace_theme(reference:) || fallback_theme
    end

    private

    attr_reader :workspace

    def system_theme
      @system_theme ||= SystemTheme.new(workspace:)
    end

    def workspace_theme(reference:)
      return nil unless reference.to_s.start_with?('workspace_theme:')

      theme_id = reference.to_s.delete_prefix('workspace_theme:').to_i
      return nil if theme_id.zero?

      workspace.visualization_themes.find_by(id: theme_id)
    end

    def fallback_theme
      workspace.default_visualization_theme || system_theme
    end
  end
end
