# frozen_string_literal: true

module App
  module Admin
    module TranslationsHelper
      def translation_value_for(translation_key:, locale:, suggestions:)
        suggestion = suggestions.dig(translation_key.id.to_s, locale)
        return suggestion if suggestion.present?

        translation_key.translation_values.find { |value| value.locale == locale }&.value.to_s
      end

      def used_in_entries(translation_key:)
        Array(translation_key.used_in).map do |entry|
          {
            label: (entry['label'] || entry[:label]).to_s,
            path: (entry['path'] || entry[:path]).to_s
          }
        end
      end

      def used_in_path_linkable?(path:)
        path.present? && path.start_with?('/')
      end

      def duplicate_english_count_for(value:, duplicate_counts:)
        duplicate_counts[value.to_s.downcase]
      end
    end
  end
end
