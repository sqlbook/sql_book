# frozen_string_literal: true

module Translations
  class CatalogSyncService
    LOCALE_FILE_PATH = Rails.root.join('config/locales/en.yml').freeze

    class << self
      def sync_from_locale_file!
        locale_data = YAML.safe_load_file(LOCALE_FILE_PATH)
        english_tree = locale_data.fetch('en', {})
        flatten(english_tree).each do |key, value|
          sync_key!(key:, english_value: value.to_s)
        end
      end

      private

      def sync_key!(key:, english_value:)
        translation_key = TranslationKey.find_or_create_by!(key:) do |record|
          defaults = default_metadata_for(key:)
          record.area_tags = defaults[:area_tags]
          record.type_tags = defaults[:type_tags]
          record.used_in = defaults[:used_in]
        end

        translation_value = TranslationValue.find_or_initialize_by(translation_key:, locale: 'en')
        return if translation_value.persisted? && translation_value.value.present?

        translation_value.update!(value: english_value, source: 'seed')
      end

      def flatten(hash, prefix = nil, result = {})
        hash.each do |key, value|
          nested_key = [prefix, key].compact.join('.')
          case value
          when Hash
            flatten(value, nested_key, result)
          else
            result[nested_key] = value
          end
        end
        result
      end

      def default_metadata_for(key:) # rubocop:disable Metrics/MethodLength
        area_tag = key.split('.').first
        type_tag =
          if key.include?('title')
            'title'
          elsif key.include?('body')
            'body'
          elsif key.include?('subject')
            'email_subject'
          else
            'copy'
          end

        {
          area_tags: [area_tag],
          type_tags: [type_tag],
          used_in: []
        }
      end # rubocop:enable Metrics/MethodLength
    end
  end
end
