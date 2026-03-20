# frozen_string_literal: true

module DataSources
  class ConnectionValidationService
    Result = Struct.new(:success?, :available_tables, :checked_at, :error_code, :message, keyword_init: true)

    def initialize(source_type:, attributes:)
      @source_type = source_type.to_s
      @attributes = attributes.deep_symbolize_keys
    end

    def call
      connector.validate_connection!

      Result.new(
        success?: true,
        available_tables: connector.list_tables(include_columns: false),
        checked_at: Time.current,
        error_code: nil,
        message: nil
      )
    rescue Connectors::BaseConnector::ConnectionError => e
      Rails.logger.warn("Data source connection validation failed: #{source_type} #{e.class}")
      failure(code: 'connection_failed', message: I18n.t('app.workspaces.data_sources.validation.connection_failed'))
    rescue StandardError => e
      Rails.logger.error("Data source connection validation failed unexpectedly: #{source_type} #{e.class}")
      failure(code: 'connection_failed', message: I18n.t('app.workspaces.data_sources.validation.connection_failed'))
    end

    private

    attr_reader :source_type, :attributes

    def connector
      @connector ||= ConnectorFactory.build(source_type:, attributes:)
    end

    def failure(code:, message:)
      Result.new(success?: false, available_tables: [], checked_at: nil, error_code: code, message:)
    end
  end
end
