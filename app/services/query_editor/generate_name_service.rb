# frozen_string_literal: true

module QueryEditor
  class GenerateNameService
    Result = Struct.new(
      :success?,
      :code,
      :message,
      :generated_name,
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

      success(
        generated_name: generated_name_for(data_source: selected_data_source)
      )
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

    def generated_name_for(data_source:)
      return nil if attributes['name'].to_s.strip.present?

      Queries::GeneratedNameService.generate(
        sql:,
        data_source:,
        actor:,
        schema_context: Queries::SchemaContextBuilder.call(data_source:)
      )
    rescue Queries::GeneratedNameService::ConfigurationError, Queries::GeneratedNameService::RequestError => e
      Rails.logger.warn("Query editor async name generation failed: #{e.class} #{e.message}")
      nil
    end

    def sql_required_failure
      failure(
        code: 'query.sql_required',
        message: I18n.t('app.workspaces.queries.editor.errors.sql_required')
      )
    end

    def success(generated_name:)
      Result.new(
        success?: true,
        code: 'query_editor.generated_name',
        message: nil,
        generated_name:
      )
    end

    def failure(code:, message:)
      Result.new(
        success?: false,
        code:,
        message:,
        generated_name: nil
      )
    end
  end
end
