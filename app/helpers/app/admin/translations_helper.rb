# frozen_string_literal: true

module App
  module Admin
    module TranslationsHelper
      def translation_value_for(translation_key:, locale:, suggestions:)
        suggestion = suggestions.dig(translation_key.id.to_s, locale)
        return suggestion if suggestion.present?

        translation_key.translation_values.find { |value| value.locale == locale }&.value.to_s
      end

      def used_in_lines(translation_key:)
        Array(translation_key.used_in).map do |entry|
          label = entry['label'] || entry[:label]
          path = entry['path'] || entry[:path]
          "#{label} | #{path}"
        end.join("\n")
      end
    end
  end
end
