# frozen_string_literal: true

module Queries
  class UpdateService # rubocop:disable Metrics/ClassLength
    Result = Struct.new(
      :success?,
      :query,
      :message,
      :error_code,
      :update_outcome,
      :conflicting_query,
      keyword_init: true
    )

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if missing_update_attributes?
        return failure(message: I18n.t('app.workspaces.chat.query_library.update_query_required'))
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
      failure(message: e.message, code: e.code || 'validation_error')
    end

    private

    attr_reader :workspace, :actor, :attributes, :fingerprint

    def resolve_query
      query_id = attributes['query_id'].to_i
      return failure(message: I18n.t('app.workspaces.chat.query_library.update_query_required')) if query_id.zero?

      query_scope.find_by(id: query_id) || failure(message: I18n.t('app.workspaces.chat.query_library.query_not_found'))
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
        message: nil,
        error_code: nil,
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
        message: I18n.t(
          'app.workspaces.chat.query_library.duplicate_saved_query',
          name: conflicting_query.name
        ),
        error_code: 'duplicate_saved_query',
        update_outcome: nil,
        conflicting_query:
      )
    end

    def failure(message:, code: 'validation_error')
      Result.new(
        success?: false,
        query: nil,
        message:,
        error_code: code,
        update_outcome: nil,
        conflicting_query: nil
      )
    end
  end
end
