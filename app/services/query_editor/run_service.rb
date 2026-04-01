# frozen_string_literal: true

module QueryEditor
  class RunService
    Result = Struct.new(
      :success?,
      :code,
      :message,
      :query_result,
      :generated_name,
      :run_token,
      :data_source,
      keyword_init: true
    )

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call
      return sql_required_failure if sql.blank?

      selected_data_source = resolve_data_source
      return selected_data_source if selected_data_source.is_a?(Result)

      DataSources::QuerySafetyGuard.validate!(sql:)
      build_success_result(data_source: selected_data_source)
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(code: normalized_query_code(e.code), message: e.message)
    end

    private

    attr_reader :workspace, :actor, :attributes

    def sql
      @sql ||= attributes['sql'].to_s.strip
    end

    def resolve_data_source
      data_source = workspace.data_sources.find_by(id: attributes['data_source_id'].to_i)
      return data_source if data_source.present?

      failure(
        code: 'query.data_source_not_found',
        message: I18n.t('app.workspaces.queries.editor.errors.data_source_not_found')
      )
    end

    def build_success_result(data_source:)
      query_result = draft_query_for(data_source:).query_result

      Result.new(
        success?: true,
        code: 'query_editor.ran',
        message: nil,
        query_result:,
        generated_name: generated_name_for(data_source:, query_result:),
        run_token: issued_run_token(data_source:, query_result:),
        data_source:
      )
    end

    def draft_query_for(data_source:)
      Query.new(
        query: sql,
        name: attributes['name'].to_s.strip.presence,
        data_source:,
        author: actor
      )
    end

    def issued_run_token(data_source:, query_result:)
      return nil if query_result.error

      RunToken.issue(data_source_id: data_source.id, sql:)
    end

    def generated_name_for(data_source:, query_result:)
      return nil if query_result.error
      return nil unless request_generated_name?
      return nil if attributes['name'].to_s.strip.present?

      Queries::GeneratedNameService.generate(
        sql:,
        data_source:,
        actor:,
        schema_context: Queries::SchemaContextBuilder.call(data_source:)
      )
    rescue Queries::GeneratedNameService::ConfigurationError, Queries::GeneratedNameService::RequestError => e
      Rails.logger.warn("Query editor name generation failed: #{e.class} #{e.message}")
      nil
    end

    def request_generated_name?
      ActiveModel::Type::Boolean.new.cast(attributes['request_generated_name'])
    end

    def sql_required_failure
      failure(
        code: 'query.sql_required',
        message: I18n.t('app.workspaces.queries.editor.errors.sql_required')
      )
    end

    def failure(code:, message:)
      Result.new(
        success?: false,
        code:,
        message:,
        query_result: nil,
        generated_name: nil,
        run_token: nil,
        data_source: nil
      )
    end

    def normalized_query_code(code)
      return 'query.validation_error' if code.blank?
      return code if code.to_s.include?('.')

      "query.#{code}"
    end
  end
end
