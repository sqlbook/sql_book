# frozen_string_literal: true

module Translations
  class CatalogSyncService
    LOCALE_FILE_PATH = Rails.root.join('config/locales/en.yml').freeze
    USED_IN_RULES = [
      { pattern: /\Acommon\./, entries: [{ label: 'Shared copy' }] },
      { pattern: /\Aadmin\.translations\./, entries: [{ label: 'Admin page', path: '/app/admin/translations' }] },
      {
        pattern: /\Aapp\.account_settings\./,
        entries: [{ label: 'Account settings page', path: '/app/account-settings' }]
      },
      { pattern: /\Aapp\.navigation\./, entries: [{ label: 'App header navigation', path: '/app/workspaces' }] },
      { pattern: /\Aauth\./, entries: [{ label: 'Authentication flow', path: '/auth/login' }] },
      { pattern: /\Atoasts\./, entries: [{ label: 'Toast' }] },
      { pattern: /\Amailers\./, entries: [{ label: 'Email' }] }
    ].freeze
    AREA_TAG_PREFIXES = {
      'common' => 'common.',
      'email' => 'mailers.',
      'toast' => 'toasts.',
      'authentication' => 'auth.',
      'account_settings' => 'app.account_settings.',
      'navigation' => 'app.navigation.',
      'admin' => 'admin.'
    }.freeze
    SPECIFIC_HEADING_TYPE_TAGS = {
      'admin.translations.title' => 'h1',
      'app.account_settings.title' => 'h1',
      'app.account_settings.delete_account.dialog.title' => 'h3',
      'app.account_settings.delete_account.confirm_label' => 'h4'
    }.freeze
    TYPE_TAG_RULES = [
      [->(key) { key.include?('.subjects.') }, 'email_subject'],
      [->(key) { key.include?('.actions.') }, 'button'],
      [->(key) { key.include?('.fields.') }, 'label'],
      [->(key) { key.include?('.placeholders.') }, 'placeholder'],
      [->(key) { key.include?('.tabs.') }, 'tab'],
      [->(key) { key.include?('.aria.') }, 'aria_label'],
      [->(key) { key.end_with?('.body') }, 'body'],
      [->(key) { key.include?('.description') || key.include?('.guidance.') || key.end_with?('.empty_state') }, 'copy'],
      [->(key) { key.end_with?('.title') }, 'title']
    ].freeze

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
        translation_key = TranslationKey.find_or_create_by!(key:)
        metadata = default_metadata_for(key:, translation_key:)
        translation_key.update!(metadata)

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

      def default_metadata_for(key:, translation_key:)
        {
          area_tags: merged_tags(existing: translation_key.area_tags, generated: inferred_area_tags(key:)),
          type_tags: merged_tags(existing: translation_key.type_tags, generated: inferred_type_tags(key:)),
          used_in: inferred_used_in(key:)
        }
      end

      def merged_tags(existing:, generated:)
        (Array(existing) + Array(generated)).map(&:to_s).map(&:strip).compact_blank.uniq.sort
      end

      def inferred_area_tags(key:)
        tags = [key.split('.').first]
        AREA_TAG_PREFIXES.each { |tag, prefix| tags << tag if key.start_with?(prefix) }
        tags.compact_blank.uniq
      end

      def inferred_type_tags(key:)
        specific_heading = SPECIFIC_HEADING_TYPE_TAGS[key]
        return [specific_heading] if specific_heading

        inferred_tag = TYPE_TAG_RULES.find { |matcher, _tag| matcher.call(key) }&.last
        [inferred_tag || 'copy']
      end

      def inferred_used_in(key:)
        rule = USED_IN_RULES.find { |candidate| key.match?(candidate[:pattern]) }
        return [] unless rule

        Array(rule[:entries]).map(&:dup)
      end
    end
  end
end
