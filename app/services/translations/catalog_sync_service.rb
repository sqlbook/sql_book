# frozen_string_literal: true

module Translations
  class CatalogSyncService # rubocop:disable Metrics/ClassLength
    LOCALE_FILE_PATH = Rails.root.join('config/locales/en.yml').freeze
    EXCLUDED_KEY_PREFIXES = %w[admin. toasts.admin.].freeze
    KEY_USAGE_BY_PATH_RULES = [
      {
        pattern: %r{\Aapp/views/app/workspaces/settings/_team},
        entry: { label: 'Workspace Settings > Team', path: '/app/workspaces/:workspace_id/workspace-settings?tab=team' }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/settings/_subscription},
        entry: {
          label: 'Workspace Settings > Subscription',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=subscription'
        }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/settings/_delete},
        entry: {
          label: 'Workspace Settings > Delete Workspace',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=delete'
        }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/settings/_general},
        entry: {
          label: 'Workspace Settings > General',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=general'
        }
      },
      {
        pattern: %r{\Aapp/views/app/account_settings/},
        entry: { label: 'Account Settings > General', path: '/app/account-settings?tab=general' }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/settings/},
        entry: {
          label: 'Workspace Settings > General',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=general'
        }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/data_sources/},
        entry: { label: 'Data Sources', path: '/app/workspaces/:workspace_id/data_sources' }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/queries/},
        entry: { label: 'Query Library', path: '/app/workspaces/:workspace_id/queries' }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/dashboards/},
        entry: { label: 'Dashboards', path: '/app/workspaces/:workspace_id/dashboards' }
      },
      {
        pattern: %r{\Aapp/views/app/workspaces/index},
        entry: { label: 'Workspaces page', path: '/app/workspaces' }
      },
      {
        pattern: %r{\Aapp/views/shared/},
        entry: { label: 'Header navigation', path: '/app/workspaces/:workspace_id' }
      },
      { pattern: %r{\Aapp/views/auth/}, entry: { label: 'Authentication flow', path: '/auth/login' } },
      { pattern: %r{\Aapp/views/.*mailer}, entry: { label: 'Email' } }
    ].freeze
    USED_IN_RULES = [
      {
        pattern: /\Aapp\.account_settings\.delete_account\./,
        entries: [{ label: 'Account Settings > Delete Account', path: '/app/account-settings?tab=delete_account' }]
      },
      {
        pattern: /\Aapp\.account_settings\./,
        entries: [{ label: 'Account Settings > General', path: '/app/account-settings?tab=general' }]
      },
      {
        pattern: /\Aapp\.navigation\./,
        entries: [{ label: 'Header navigation', path: '/app/workspaces/:workspace_id' }]
      },
      { pattern: /\Aauth\./, entries: [{ label: 'Authentication flow', path: '/auth/login' }] },
      {
        pattern: /\Atoasts\.workspaces\.members\./,
        entries: [{
          label: 'Workspace Settings > Team / Toast',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=team'
        }]
      },
      {
        pattern: /\Atoasts\.workspaces\./,
        entries: [{
          label: 'Workspace Settings > General / Toast',
          path: '/app/workspaces/:workspace_id/workspace-settings?tab=general'
        }]
      },
      {
        pattern: /\Atoasts\.account_settings\./,
        entries: [{ label: 'Account Settings / Toast', path: '/app/account-settings?tab=general' }]
      },
      { pattern: /\Atoasts\./, entries: [{ label: 'Toast' }] },
      { pattern: /\Amailers\./, entries: [{ label: 'Email' }] }
    ].freeze
    AREA_TAG_PREFIXES = {
      'common' => 'common.',
      'email' => 'mailers.',
      'toast' => 'toasts.',
      'authentication' => 'auth.',
      'account_settings' => 'app.account_settings.',
      'navigation' => 'app.navigation.'
    }.freeze
    AREA_TAG_NORMALIZATION = {
      'auth' => 'authentication',
      'toasts' => 'toast',
      'mailers' => 'email'
    }.freeze
    SPECIFIC_HEADING_TYPE_TAGS = {
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
        remove_excluded_keys!
        locale_data = YAML.safe_load_file(LOCALE_FILE_PATH)
        english_tree = locale_data.fetch('en', {})
        flatten(english_tree).each do |key, value|
          next if excluded_key?(key:)

          sync_key!(key:, english_value: value.to_s)
        end
      end

      private

      def remove_excluded_keys!
        table = TranslationKey.arel_table
        query = EXCLUDED_KEY_PREFIXES
          .map { |prefix| table[:key].matches("#{prefix}%") }
          .reduce { |memo, clause| memo.or(clause) }
        TranslationKey.where(query).destroy_all if query
      end

      def excluded_key?(key:)
        EXCLUDED_KEY_PREFIXES.any? { |prefix| key.start_with?(prefix) }
      end

      def sync_key!(key:, english_value:)
        translation_key = TranslationKey.find_or_create_by!(key:)
        metadata = default_metadata_for(key:, translation_key:)
        translation_key.update!(metadata)

        translation_value = TranslationValue.find_or_initialize_by(translation_key:, locale: 'en')
        return if translation_value.persisted? && translation_value.value.to_s == english_value

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
          area_tags: merged_area_tags(existing: translation_key.area_tags, generated: inferred_area_tags(key:)),
          type_tags: merged_type_tags(existing: translation_key.type_tags, generated: inferred_type_tags(key:)),
          used_in: inferred_used_in(key:)
        }
      end

      def merged_area_tags(existing:, generated:)
        (Array(existing) + Array(generated))
          .map(&:to_s)
          .map(&:strip)
          .map { |tag| normalize_area_tag(tag:) }
          .compact_blank
          .uniq
          .sort
      end

      def merged_type_tags(existing:, generated:)
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
        return inferred_common_used_in(key:) if key.start_with?('common.')

        rule = USED_IN_RULES.find { |candidate| key.match?(candidate[:pattern]) }
        return [] unless rule

        Array(rule[:entries]).map(&:dup)
      end

      def inferred_common_used_in(key:)
        usage_map = common_key_usage_map
        Array(usage_map[key]).map(&:dup)
      end

      def common_key_usage_map
        @common_key_usage_map ||= begin
          usage = Hash.new { |hash, common_key| hash[common_key] = [] }
          Rails.root.glob('app/views/**/*.erb').each do |file_path|
            register_common_key_usage!(usage:, file_path:)
          end
          usage.transform_values(&:uniq)
        end
      end

      def register_common_key_usage!(usage:, file_path:)
        contents = File.read(file_path)
        common_keys_in(contents).each do |common_key|
          entry = entry_for_view_path(path: file_path)
          usage[common_key] << entry if entry
        end
      end

      def common_keys_in(contents)
        contents.scan(/I18n\.t\(['"]((?:common)\.[^'"]+)['"]\)/).flatten
      end

      def entry_for_view_path(path:)
        normalized_path = Pathname(path).relative_path_from(Rails.root).to_s
        rule = KEY_USAGE_BY_PATH_RULES.find { |candidate| normalized_path.match?(candidate[:pattern]) }
        rule&.fetch(:entry)&.dup
      end

      def normalize_area_tag(tag:)
        AREA_TAG_NORMALIZATION.fetch(tag, tag)
      end
    end
  end # rubocop:enable Metrics/ClassLength
end
