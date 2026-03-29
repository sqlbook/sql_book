# frozen_string_literal: true

module Queries
  class SaveService # rubocop:disable Metrics/ClassLength
    Result = Struct.new(
      :success?,
      :query,
      :code,
      :fallback_message,
      :save_outcome,
      :conflicting_query,
      :proposed_name,
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

    def call
      return failure(code: 'query.sql_required', fallback_message: 'Please provide SQL to save.') if sql.blank?

      data_source = resolve_data_source
      return data_source if data_source.is_a?(Result)

      DataSources::QuerySafetyGuard.validate!(sql:)
      persist_saved_query_for(data_source:)
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(code: normalized_query_code(e.code), fallback_message: e.message)
    end

    private

    attr_reader :workspace, :actor, :attributes

    def sql
      @sql ||= attributes['sql'].to_s.strip
    end

    def explicit_name
      @explicit_name ||= attributes['name'].to_s.strip.presence
    end

    def query_name_for(data_source:)
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
        failure(code: 'query.data_source_not_found', fallback_message: 'I could not find that data source.')
    end

    def resolve_data_source_by_name
      requested_name = attributes['data_source_name'].to_s.strip.downcase
      return nil if requested_name.blank?

      workspace.data_sources.find do |data_source|
        data_source.display_name.to_s.downcase == requested_name ||
          data_source.name.to_s.downcase == requested_name
      end
    end

    def create_query!(data_source:, name:)
      Query.create!(
        data_source:,
        author: actor,
        last_updated_by: actor,
        name:,
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

    def persist_saved_query_for(data_source:)
      existing_query = existing_saved_query_for(data_source:)
      return success(query: existing_query, save_outcome: 'already_saved') if existing_query

      generated_name = query_name_for(data_source:)
      conflicting_query = generated_name_conflict_for(name: generated_name)
      return generated_name_conflict_failure(conflicting_query:, proposed_name: generated_name) if conflicting_query

      success(query: create_query!(data_source:, name: generated_name), save_outcome: 'created')
    end

    def generated_name_conflict_for(name:)
      return nil if explicit_name.present?
      return nil if name.to_s.strip.blank?

      workspace_saved_queries.find do |query|
        query.name.to_s.casecmp?(name)
      end
    end

    def workspace_saved_queries
      @workspace_saved_queries ||= Query.joins(:data_source)
        .includes(:data_source, :author)
        .where(saved: true, data_sources: { workspace_id: workspace.id })
        .to_a
    end

    def success(query:, save_outcome:)
      Result.new(
        success?: true,
        query:,
        code: save_outcome == 'already_saved' ? 'query.already_saved' : 'query.saved',
        fallback_message: nil,
        save_outcome:,
        conflicting_query: nil,
        proposed_name: nil
      )
    end

    def generated_name_conflict_failure(conflicting_query:, proposed_name:)
      Result.new(
        success?: false,
        query: nil,
        code: 'query.generated_name_conflict',
        fallback_message: [
          "I can save this as \"#{proposed_name}\",",
          "but a different saved query already uses that name (#{conflicting_query.name})."
        ].join(' '),
        save_outcome: nil,
        conflicting_query:,
        proposed_name:
      )
    end

    def failure(code:, fallback_message: nil)
      Result.new(
        success?: false,
        query: nil,
        code:,
        fallback_message:,
        save_outcome: nil,
        conflicting_query: nil,
        proposed_name: nil
      )
    end

    def normalized_query_code(code)
      return 'query.validation_error' if code.blank?
      return code if code.to_s.include?('.')

      "query.#{code}"
    end
  end
end
