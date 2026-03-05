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
        TranslationValue
          .joins(:translation_key)
          .find_by(locale:, translation_keys: { key: })
          &.value
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def normalize_locale(locale)
        locale.to_s.downcase
      end
    end
  end
end
