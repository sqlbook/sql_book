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

      fingerprint = fingerprint_for(query:, sql: new_sql)
      conflicting_query = conflicting_saved_query_for(query:, fingerprint:)
      return duplicate_failure(conflicting_query:) if conflicting_query

      updates = build_updates(query:, sql: new_sql, name: new_name, fingerprint:)
      return success(query:, update_outcome: 'unchanged') if updates.blank?

      query.update!(updates)
      success(query: query.reload, update_outcome: 'updated')
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(message: e.message, code: e.code || 'validation_error')
    end

    private

    attr_reader :workspace, :actor, :attributes

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

    def build_updates(query:, sql:, name:, fingerprint:)
      updates = {
        last_updated_by: actor,
        saved: true
      }

      if sql.present? && Queries::Fingerprint.normalize_sql(sql) != Queries::Fingerprint.normalize_sql(query.query)
        updates[:query] = sql
      end
      updates[:name] = name if name.present? && name != query.name
      updates[:query_fingerprint] = fingerprint if fingerprint.present? && fingerprint != query.query_fingerprint

      updates.compact
    end

    def fingerprint_for(query:, sql:)
      Queries::Fingerprint.build(data_source_id: query.data_source_id, sql:)
    end

    def conflicting_saved_query_for(query:, fingerprint:)
      return nil if fingerprint.blank?

      query_scope
        .where.not(id: query.id)
        .find_by(query_fingerprint: fingerprint)
    end

    def query_scope
      Query.joins(:data_source)
        .includes(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
        .where(saved: true)
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
