# frozen_string_literal: true

module Visualizations
  class ThemeDuplicateService
    Result = Struct.new(:success?, :theme, :code, :message, keyword_init: true)

    def initialize(workspace:, source_theme:)
      @workspace = workspace
      @source_theme = source_theme
    end

    def call
      duplicated = workspace.visualization_themes.create!(
        name: next_name,
        theme_json_dark: source_theme.theme_json_dark,
        theme_json_light: source_theme.theme_json_light,
        default: false
      )

      Result.new(success?: true, theme: duplicated, code: 'visualization_theme.duplicated', message: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, theme: nil, code: 'visualization_theme.invalid', message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :workspace, :source_theme

    def next_name
      base_name = "#{source_theme.name} #{I18n.t('app.workspaces.settings.branding.copy_suffix')}"
      return base_name unless workspace.visualization_themes.exists?(name: base_name)

      suffix = 2
      loop do
        candidate = "#{base_name} #{suffix}"
        return candidate unless workspace.visualization_themes.exists?(name: candidate)

        suffix += 1
      end
    end
  end
end
