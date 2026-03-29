# frozen_string_literal: true

require 'yaml'

module Chat
  class CopyAudit # rubocop:disable Metrics/ClassLength
    LOCALE_ROOT = %w[en app workspaces chat].freeze
    RETAINED_NAMESPACES = %w[
      action_labels
      cards
      composer
      datasource_setup
      errors
      messages
      planner
      query
      query_card
      sidebar
      statuses
      suggestions
      threads
      title
    ].freeze
    DEPRECATED_NAMESPACES = %w[datasource executor query_library responses].freeze
    KEY_CLASSIFICATION_RULES = [
      [/\Aaction_labels\./, 'ui_or_fallback_keep'],
      [/\Acards\./, 'ui_or_fallback_keep'],
      [/\Acomposer\./, 'ui_or_fallback_keep'],
      [/\Adatasource_setup\./, 'model_phrase'],
      [/\Aerrors\./, 'ui_or_fallback_keep'],
      [/\Amessages\./, 'ui_or_fallback_keep'],
      [/\Aplanner\./, 'model_phrase'],
      [/\Aquery_card\./, 'ui_or_fallback_keep'],
      [/\Asidebar\./, 'ui_or_fallback_keep'],
      [/\Astatuses\./, 'ui_or_fallback_keep'],
      [/\Asuggestions\./, 'ui_or_fallback_keep'],
      [/\Athreads\./, 'ui_or_fallback_keep'],
      [/\Atitle\z/, 'ui_or_fallback_keep'],
      [/\Aquery\.ask_scope(?:_read_only)?\z/, 'model_phrase'],
      [/\Aquery\.ask_for_table_or_metric\z/, 'model_phrase'],
      [/\Aquery\.result_intro(?:_refined)?\z/, 'model_phrase'],
      [/\Aquery\.no_rows\z/, 'ui_or_fallback_keep'],
      [/\A(?:datasource|executor|query_library|responses)\./, 'legacy_delete']
    ].freeze
    CONSUMER_GLOBS = %w[
      app/**/*.rb
      app/**/*.erb
      app/**/*.ts
      app/**/*.js
      lib/**/*.rb
      lib/**/*.rake
      spec/**/*.rb
    ].freeze
    APP_CONSUMER_GLOBS = %w[
      app/**/*.rb
      app/**/*.erb
      app/**/*.ts
      app/**/*.js
      lib/**/*.rb
      lib/**/*.rake
    ].freeze
    HARD_CODED_GLOBS = %w[
      app/services/chat/**/*.rb
      app/services/tooling/**/*.rb
      app/services/queries/**/*.rb
      app/controllers/api/**/*.rb
      app/controllers/app/workspaces/**/*chat*.rb
    ].freeze
    HARD_CODED_CONTEXT_REGEXES = [
      /assistant_message:\s*["'](?<text>[^"']*[A-Za-z][^"']*)["']/,
      /fallback_message:\s*["'](?<text>[^"']*[A-Za-z][^"']*)["']/,
      /render_non_action\(["'](?<text>[^"']*[A-Za-z][^"']*)["']/,
      /normalized_message_candidate\(["'](?<text>[^"']*[A-Za-z][^"']*)["']/,
      /return\s+["'](?<text>[^"']*[A-Za-z][^"']*)["']/
    ].freeze

    def initialize(root: Rails.root)
      @root = Pathname(root)
    end

    def report
      {
        'generated_at' => Time.current.utc.iso8601,
        'summary' => summary,
        'locale_keys' => locale_key_entries,
        'deprecated_namespace_consumers' => deprecated_namespace_consumers,
        'hardcoded_strings' => hardcoded_string_entries
      }
    end

    def summary
      {
        'locale_leaf_count' => locale_keys.count,
        'retained_namespaces' => RETAINED_NAMESPACES,
        'deprecated_namespaces' => DEPRECATED_NAMESPACES,
        'unclassified_key_count' => unclassified_keys.count,
        'deprecated_consumer_count' => deprecated_namespace_consumers.count,
        'hardcoded_string_count' => hardcoded_string_entries.count
      }
    end

    def locale_keys
      @locale_keys ||= flatten_hash(locale_tree).keys.sort
    end

    def locale_key_entries
      @locale_key_entries ||= locale_keys.map do |key|
        {
          'key' => key,
          'namespace' => key.split('.').first,
          'classification' => classify_key(key),
          'app_consumers' => consumers_for(key, app_only: true),
          'spec_consumers' => consumers_for(key, app_only: false, spec_only: true)
        }
      end
    end

    def unclassified_keys
      locale_key_entries.select { |entry| entry['classification'] == 'unclassified' }
    end

    def keys_outside_retained_namespaces
      locale_key_entries.reject do |entry|
        RETAINED_NAMESPACES.include?(entry['namespace'])
      end
    end

    def deprecated_namespace_consumers
      @deprecated_namespace_consumers ||= DEPRECATED_NAMESPACES.flat_map do |namespace|
        consumer_entries_for(full_key_prefix: "app.workspaces.chat.#{namespace}.", app_only: true).map do |entry|
          entry.merge('namespace' => namespace)
        end
      end
    end

    def hardcoded_string_entries
      @hardcoded_string_entries ||= tracked_files(HARD_CODED_GLOBS).flat_map do |file_path|
        extract_hardcoded_strings(file_path:)
      end
    end

    private

    attr_reader :root

    def locale_tree
      YAML.load_file(root.join('config/locales/en.yml')).dig(*LOCALE_ROOT) || {}
    end

    def flatten_hash(node, prefix = [], output = {})
      node.each do |key, value|
        path = prefix + [key.to_s]
        if value.is_a?(Hash)
          flatten_hash(value, path, output)
        else
          output[path.join('.')] = value
        end
      end
      output
    end

    def classify_key(key)
      rule = KEY_CLASSIFICATION_RULES.find { |pattern, _classification| key.match?(pattern) }
      rule ? rule.last : 'unclassified'
    end

    def consumers_for(key, app_only: false, spec_only: false)
      prefix = "app.workspaces.chat.#{key}"
      consumer_entries_for(full_key_prefix: prefix, app_only:, spec_only:).map do |entry|
        "#{entry['file']}:#{entry['line']}"
      end
    end

    def consumer_entries_for(full_key_prefix:, app_only: false, spec_only: false) # rubocop:disable Metrics/MethodLength
      glob_patterns = if spec_only
                        ['spec/**/*.rb']
                      elsif app_only
                        APP_CONSUMER_GLOBS
                      else
                        CONSUMER_GLOBS
                      end

      tracked_files(glob_patterns).flat_map do |file_path|
        entries = []
        File.foreach(file_path).with_index(1) do |line, line_number|
          next unless line.include?(full_key_prefix)

          entries << {
            'file' => relative_path(file_path),
            'line' => line_number,
            'source' => line.strip
          }
        end
        entries
      end
    end

    def extract_hardcoded_strings(file_path:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      relative = relative_path(file_path)

      File.readlines(file_path).each_with_index.filter_map do |line, index|
        next if line.include?('I18n.t(') || line.include?('I18n.translate(')
        next if line.strip.start_with?('#')

        match = HARD_CODED_CONTEXT_REGEXES.lazy.map { |regex| line.match(regex) }.find(&:present?)
        next unless match

        text = match[:text].to_s.strip
        next if text.blank?
        next if text.start_with?('app.workspaces.chat.')

        {
          'file' => relative,
          'line' => index + 1,
          'text' => text,
          'classification' => classify_hardcoded_string(relative:)
        }
      end
    end

    def classify_hardcoded_string(relative:)
      return 'structured_domain_result' if relative.start_with?('app/services/tooling/', 'app/services/queries/')
      return 'structured_domain_result' if relative == 'app/services/chat/action_executor.rb'
      return 'model_phrase' if relative.start_with?('app/services/chat/')

      'ui_or_fallback_keep'
    end

    def tracked_files(globs)
      globs.flat_map { |glob| Dir.glob(root.join(glob)) }
        .select { |path| File.file?(path) }
        .sort
    end

    def relative_path(file_path)
      Pathname(file_path).relative_path_from(root).to_s
    end
  end
end
