# frozen_string_literal: true

module Visualizations
  class ThemeDefaultService
    Result = Struct.new(:success?, :theme, :code, :message, keyword_init: true)

    def initialize(theme:)
      @theme = theme
    end

    def call
      theme.update!(default: true)
      Result.new(success?: true, theme:, code: 'visualization_theme.default_set', message: nil)
    rescue ActiveRecord::RecordInvalid
      Result.new(success?: false, theme:, code: 'visualization_theme.invalid', message: theme.errors.full_messages.to_sentence)
    end

    private

    attr_reader :theme
  end
end
