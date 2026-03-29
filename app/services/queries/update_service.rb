# frozen_string_literal: true

module Queries
  class UpdateService # rubocop:disable Metrics/ClassLength
    Result = Struct.new(
      :success?,
      :query,
      :code,
      :fallback_message,
      :update_outcome,
      :conflicting_query,
      keyword_init: true
    ) do
      def message
        fallback_message
      end

      def error_code
        return code unless code.to_s.include?('.')

        _namespace, remainder = code.to_s.split('.', 2)
        remainder.to_s.tr('.', '_')
      end
    end

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if missing_update_attributes?
        return failure(code: 'query.update_required', fallback_message: 'Please provide changes for the saved query.')
      end

      query = resolve_query
      return query if query.is_a?(Result)

      new_sql = resolved_sql(query:)
      new_name = resolved_name(query:)
      should_save = should_save_query?(query:)
      duplicate_resolution = resolve_duplicate(query:, sql: new_sql, should_save:)
      return duplicate_resolution if duplicate_resolution

      updates = build_updates(query:, sql: new_sql, name: new_name, fingerprint:, should_save:)
      return success(query:, update_outcome: 'unchanged') if updates.blank?

      query.update!(updates)
      success(query: query.reload, update_outcome: 'updated')
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(code: normalized_query_code(e.code), fallback_message: e.message)
    end

    private

    attr_reader :workspace, :actor, :attributes, :fingerprint

    def resolve_query
      query_id = attributes['query_id'].to_i
      if query_id.zero?
        return failure(code: 'query.update_required',
                       fallback_message: 'Please specify which saved query to update.')
      end

      query_scope.find_by(id: query_id) || failure(code: 'query.not_found',
                                                   fallback_message: 'I could not find that saved query.')
    end

    def resolved_sql(query:)
      return query.query if attributes['sql'].nil?

      sql = attributes['sql'].to_s
      return nil if sql.strip.blank?

      DataSources::QuerySafetyGuard.validate!(sql:)
      sql.strip
    end

    def resolved_name(query:)
      return query.name if attributes['name'].nil?

      attributes['name'].to_s.strip.presence
    end

    def missing_update_attributes?
      attributes['sql'].nil? && attributes['name'].nil?
    end

    def should_save_query?(query:)
      query.saved? || attributes['name'].present?
    end

    def resolve_duplicate(query:, sql:, should_save:)
      @fingerprint = fingerprint_for(query:, sql:)
      conflicting_query = conflicting_saved_query_for(query:, fingerprint:, should_save:)
      return already_saved(query: conflicting_query) if duplicate_draft_save?(query:, conflicting_query:)
      return duplicate_failure(conflicting_query:) if conflicting_query

      nil
    end

    def duplicate_draft_save?(query:, conflicting_query:)
      query.saved? == false && conflicting_query.present?
    end

    def build_updates(query:, sql:, name:, fingerprint:, should_save:)
      {
        last_updated_by: actor,
        query: updated_sql(query:, sql:),
        name: updated_name(query:, name:),
        saved: saved_flag(query:, should_save:),
        query_fingerprint: updated_fingerprint(query:, fingerprint:, should_save:)
      }.compact
    end

    def fingerprint_for(query:, sql:)
      Queries::Fingerprint.build(data_source_id: query.data_source_id, sql:)
    end

    def conflicting_saved_query_for(query:, fingerprint:, should_save:)
      return nil if fingerprint.blank? || !should_save

      saved_query_scope
        .where.not(id: query.id)
        .find_by(query_fingerprint: fingerprint)
    end

    def query_scope
      Query.joins(:data_source)
        .includes(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
    end

    def saved_query_scope
      query_scope.where(saved: true)
    end

    def success(query:, update_outcome:)
      Result.new(
        success?: true,
        query:,
        code: update_code(update_outcome:),
        fallback_message: nil,
        update_outcome:,
        conflicting_query: nil
      )
    end

    def already_saved(query:)
      success(query:, update_outcome: 'already_saved')
    end

    def updated_sql(query:, sql:)
      return if sql.blank?
      return if Queries::Fingerprint.normalize_sql(sql) == Queries::Fingerprint.normalize_sql(query.query)

      sql
    end

    def updated_name(query:, name:)
      return if name.blank?
      return if name == query.name

      name
    end

    def saved_flag(query:, should_save:)
      true if should_save && !query.saved?
    end

    def updated_fingerprint(query:, fingerprint:, should_save:)
      return unless fingerprint.present? && should_save
      return if fingerprint == query.query_fingerprint

      fingerprint
    end

    def duplicate_failure(conflicting_query:)
      Result.new(
        success?: false,
        query: nil,
        code: 'query.duplicate_saved_query',
        fallback_message: "That SQL already matches the saved query \"#{conflicting_query.name}\".",
        update_outcome: nil,
        conflicting_query:
      )
    end

    def failure(code:, fallback_message: nil)
      Result.new(
        success?: false,
        query: nil,
        code:,
        fallback_message:,
        update_outcome: nil,
        conflicting_query: nil
      )
    end

    def update_code(update_outcome:)
      case update_outcome
      when 'already_saved' then 'query.already_saved'
      when 'unchanged' then 'query.unchanged'
      else
        'query.updated'
      end
    end

    def normalized_query_code(code)
      return 'query.validation_error' if code.blank?
      return code if code.to_s.include?('.')

      "query.#{code}"
    end
  end
end
