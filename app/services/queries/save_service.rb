# frozen_string_literal: true

module Queries
  class SaveService
    Result = Struct.new(:success?, :query, :message, :error_code, :save_outcome, keyword_init: true)

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call
      return failure(message: I18n.t('app.workspaces.chat.query_library.sql_required')) if sql.blank?

      data_source = resolve_data_source
      return data_source if data_source.is_a?(Result)

      DataSources::QuerySafetyGuard.validate!(sql:)

      existing_query = existing_saved_query_for(data_source:)
      return success(query: existing_query, save_outcome: 'already_saved') if existing_query

      success(query: create_query!(data_source:), save_outcome: 'created')
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(message: e.message, code: e.code || 'validation_error')
    end

    private

    attr_reader :workspace, :actor, :attributes

    def sql
      @sql ||= attributes['sql'].to_s.strip
    end

    def query_name_for(data_source:)
      explicit_name = attributes['name'].to_s.strip
      return explicit_name if explicit_name.present?

      Queries::NameGenerator.generate(
        question: attributes['question'],
        sql:,
        data_source:
      )
    end

    def resolve_data_source
      workspace.data_sources.find_by(id: attributes['data_source_id'].to_i).presence ||
        resolve_data_source_by_name ||
        failure(message: I18n.t('app.workspaces.chat.query.data_source_not_found'))
    end

    def resolve_data_source_by_name
      requested_name = attributes['data_source_name'].to_s.strip.downcase
      return nil if requested_name.blank?

      workspace.data_sources.find do |data_source|
        data_source.display_name.to_s.downcase == requested_name ||
          data_source.name.to_s.downcase == requested_name
      end
    end

    def create_query!(data_source:)
      Query.create!(
        data_source:,
        author: actor,
        last_updated_by: actor,
        name: query_name_for(data_source:),
        query: sql,
        query_fingerprint: Queries::Fingerprint.build(data_source_id: data_source.id, sql:),
        saved: true
      )
    end

    def existing_saved_query_for(data_source:)
      fingerprint = Queries::Fingerprint.build(data_source_id: data_source.id, sql:)
      return nil if fingerprint.blank?

      Query.find_by(
        data_source_id: data_source.id,
        saved: true,
        query_fingerprint: fingerprint
      )
    end

    def success(query:, save_outcome:)
      Result.new(success?: true, query:, message: nil, error_code: nil, save_outcome:)
    end

    def failure(message:, code: 'validation_error')
      Result.new(success?: false, query: nil, message:, error_code: code, save_outcome: nil)
    end
  end
end
