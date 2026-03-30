# frozen_string_literal: true

module Queries
  class NameReviewPrompt
    def initialize(current_name:, question:, sql:, data_source:, actor:)
      @current_name = current_name.to_s.squish
      @question = question.to_s.squish
      @sql = sql.to_s.strip
      @data_source = data_source
      @actor = actor
    end

    def system_prompt
      [
        'Review whether the current saved SQL query name still fits the query.',
        'Return only JSON with keys status, suggested_name, and reason.',
        'status must be one of aligned, stale, or uncertain.',
        'Use stale only when the current name is clearly misleading after the SQL change.',
        'Use aligned when the current name still makes sense.',
        'Use uncertain when a rename might help but is not clearly required.',
        'When status is stale, include a concrete suggested_name.',
        'When status is aligned or uncertain, suggested_name should be null.',
        'The name should help a user find the query later in an application query library.',
        'Base the decision on the purpose of the query, not just visible columns.',
        'If the updated request changes an obvious quantity, ranking direction,',
        'timeframe, or status named in the title, treat that as strong evidence',
        'that the current title may be stale.',
        'Use the same language as the user when the user language is clear.',
        'Do not return markdown or commentary outside the JSON object.'
      ].join(' ')
    end

    def user_prompt
      [
        locale_hint,
        "Current saved query name: #{current_name}",
        "Workspace data source: #{data_source.display_name}",
        ("Recent user request: #{question}" if question.present?),
        "SQL:\n#{sql}"
      ].compact.join("\n\n")
    end

    private

    attr_reader :current_name, :question, :sql, :data_source, :actor

    def locale_hint
      locale = actor&.preferred_locale.to_s.strip
      return if locale.blank?

      "User locale hint: #{locale}"
    end
  end
end
