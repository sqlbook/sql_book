# frozen_string_literal: true

module Visualizations
  class ThemeUpsertService
    Result = Struct.new(:success?, :theme, :code, :message, keyword_init: true)

    def initialize(workspace:, attributes:, theme: nil)
      @workspace = workspace
      @attributes = attributes.to_h.deep_stringify_keys
      @theme = theme
    end

    def call
      record = theme || workspace.visualization_themes.build
      record.assign_attributes(
        name: attributes['name'],
        default: ActiveModel::Type::Boolean.new.cast(attributes['default']),
        theme_json_dark: resolved_theme_json(mode: :dark, current: record.theme_json_dark),
        theme_json_light: resolved_theme_json(mode: :light, current: record.theme_json_light)
      )
      record.save!

      Result.new(success?: true, theme: record, code: 'visualization_theme.saved', message: nil)
    rescue ActiveRecord::RecordInvalid
      Result.new(
        success?: false,
        theme: record,
        code: 'visualization_theme.invalid',
        message: record.errors.full_messages.to_sentence
      )
    end

    private

    attr_reader :workspace, :attributes, :theme

    def resolved_theme_json(mode:, current:)
      direct_value = attributes["theme_json_#{mode}"]
      return direct_value.to_h.deep_stringify_keys if direct_value.present?

      editor_key = "editor_#{mode}"
      raw_json_key = "raw_json_#{mode}"

      ThemeFormBuilder.build(
        theme_json: current,
        editor_params: attributes.fetch(editor_key, {}).to_h.symbolize_keys,
        raw_json: attributes[raw_json_key]
      ).deep_stringify_keys
    end
  end
end
