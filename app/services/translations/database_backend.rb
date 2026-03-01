# frozen_string_literal: true

module Translations
  class DatabaseBackend
    include I18n::Backend::Base

    def available_locales
      TranslationValue.distinct.pluck(:locale).map(&:to_sym)
    rescue ActiveRecord::StatementInvalid
      []
    end

    def translate(locale, key, options = {}) # rubocop:disable Metrics/AbcSize
      raise I18n::ArgumentError, 'translation missing: locale is nil' if locale.nil?
      raise I18n::ArgumentError, 'translation missing: key is nil' if key.nil?

      value = RuntimeLookupService.fetch(locale:, key: normalize_flat_keys(key))
      throw(:exception, I18n::MissingTranslation.new(locale, key, options)) if value.nil?

      values = options.except(*I18n::RESERVED_KEYS)
      return value if values.empty? || !value.is_a?(String)

      I18n.interpolate(value, values)
    rescue I18n::ReservedInterpolationKey => e
      raise I18n::ReservedInterpolationKey.new(e.message, key)
    end # rubocop:enable Metrics/AbcSize

    private

    def normalize_flat_keys(key)
      key.is_a?(Array) ? key.join('.') : key.to_s
    end
  end
end
