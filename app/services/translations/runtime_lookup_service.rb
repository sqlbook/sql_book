# frozen_string_literal: true

module Translations
  class RuntimeLookupService
    VERSION_CACHE_KEY = 'translations:version'
    NULL_SENTINEL = '__null__'

    class << self
      def fetch(locale:, key:)
        normalized_locale = normalize_locale(locale)
        translation = read_cached(locale: normalized_locale, key:)
        return translation unless translation.nil?

        return nil if normalized_locale == I18n.default_locale.to_s

        read_cached(locale: I18n.default_locale.to_s, key:)
      end

      def bump_version!
        Rails.cache.increment(VERSION_CACHE_KEY, 1, initial: 1)
      rescue NotImplementedError
        current_version = current_version_value
        Rails.cache.write(VERSION_CACHE_KEY, current_version + 1)
      end

      def current_version_value
        Rails.cache.fetch(VERSION_CACHE_KEY) { 1 }.to_i
      end

      private

      def read_cached(locale:, key:)
        cache_key = "translations:v#{current_version_value}:#{locale}:#{key}"
        cached = Rails.cache.fetch(cache_key) { find_value(locale:, key:) || NULL_SENTINEL }
        return nil if cached == NULL_SENTINEL

        cached
      end

      def find_value(locale:, key:)
        value = TranslationValue
          .joins(:translation_key)
          .find_by(locale:, translation_keys: { key: })
          &.value
        return value if value.present?

        find_duplicate_english_match(locale:, key:)
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def find_duplicate_english_match(locale:, key:)
        source_key = source_translation_key_for(key:)
        return nil unless source_key

        source_english = source_english_value_for(source_key:)
        return nil if source_english.blank?

        duplicate_scope_for(locale:, source_key:, source_english:)
          .order(updated_at: :desc)
          .limit(1)
          .pick(:value)
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def source_translation_key_for(key:)
        TranslationKey.find_by(key:)
      end

      def source_english_value_for(source_key:)
        source_key.translation_values.find_by(locale: I18n.default_locale.to_s)&.value.to_s
      end

      def duplicate_scope_for(locale:, source_key:, source_english:)
        scope = duplicate_scope_base(locale:, source_key:, source_english:)
        apply_type_tag_overlap_filter(scope:, type_tags: source_key.type_tags)
      end

      def duplicate_scope_base(locale:, source_key:, source_english:)
        TranslationValue
          .joins(:translation_key)
          .joins(duplicate_join_sql)
          .where(locale:)
          .where.not(value: [nil, ''])
          .where.not(translation_values: { translation_key_id: source_key.id })
          .where('LOWER(source_locale_values.value) = ?', source_english.downcase)
      end

      def apply_type_tag_overlap_filter(scope:, type_tags:)
        return scope if type_tags.blank?

        scope.where('translation_keys.type_tags && ARRAY[?]::text[]', type_tags)
      end

      def duplicate_join_sql
        <<~SQL.squish
          INNER JOIN translation_values source_locale_values
            ON source_locale_values.translation_key_id = translation_values.translation_key_id
           AND source_locale_values.locale = '#{I18n.default_locale}'
        SQL
      end

      def normalize_locale(locale)
        locale.to_s.downcase
      end
    end
  end
end
