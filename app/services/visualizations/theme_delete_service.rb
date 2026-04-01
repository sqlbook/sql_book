# frozen_string_literal: true

module Visualizations
  class ThemeDeleteService
    Result = Struct.new(:success?, :code, :message, keyword_init: true)

    def initialize(theme:)
      @theme = theme
    end

    def call
      if theme.default?
        return Result.new(
          success?: false,
          code: 'visualization_theme.default_delete_forbidden',
          message: I18n.t('app.workspaces.settings.branding.errors.default_delete_forbidden')
        )
      end

      theme.destroy!
      Result.new(success?: true, code: 'visualization_theme.deleted', message: nil)
    end

    private

    attr_reader :theme
  end
end
