# frozen_string_literal: true

module Queries
  class GeneratedNamePrompt
    def initialize(existing_names:, avoid_existing_names:, **context)
      @question = context[:question].to_s.squish
      @sql = context[:sql].to_s.strip
      @data_source = context[:data_source]
      @actor = context[:actor]
      @schema_context = Array(context[:schema_context]).filter_map { |entry| entry.to_s.strip.presence }
      @existing_names = existing_names
      @avoid_existing_names = avoid_existing_names
    end

    def system_prompt
      [
        'Generate the name of a saved SQL query for an application query library.',
        'Return only the saved query name text.',
        'The name should help a user find or reference the query later.',
        'Base it on the real purpose of the query, not just the visible result columns.',
        'Reflect meaningful ranking, filtering, grouping, time-window, join, and status semantics when relevant.',
        'Use the same language as the user when the user language is clear.',
        'Be concrete and natural.',
        'Do not use quotes, markdown, commentary, or placeholder wording.',
        'Do not include the data source name unless it is needed to disambiguate.',
        ('If existing saved query names are provided, return a different name from those.' if avoid_existing_names)
      ].compact.join(' ')
    end

    def user_prompt
      [
        locale_hint,
        "Workspace data source: #{data_source.display_name}",
        schema_context_hint,
        ("User request: #{question}" if question.present?),
        "SQL:\n#{sql}",
        existing_name_hint
      ].compact.join("\n\n")
    end

    private

    attr_reader :question, :sql, :data_source, :actor, :schema_context, :existing_names, :avoid_existing_names

    def locale_hint
      locale = actor&.preferred_locale.to_s.strip
      return if locale.blank?

      "User locale hint: #{locale}"
    end

    def existing_name_hint
      return unless avoid_existing_names && existing_names.any?

      "Existing saved query names to avoid: #{existing_names.join(' | ')}"
    end

    def schema_context_hint
      return if schema_context.empty?

      "Schema context:\n- #{schema_context.join("\n- ")}"
    end
  end
end
