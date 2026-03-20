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
      success_result
    rescue Connectors::BaseConnector::ConnectionError => e
      log_failure(e, level: :warn)
      failure_result
    rescue StandardError => e
      log_failure(e, level: :error)
      failure_result
    end

    private

    attr_reader :source_type, :attributes

    def connector
      @connector ||= ConnectorFactory.build(source_type:, attributes:)
    end

    def failure(code:, message:)
      Result.new(success?: false, available_tables: [], checked_at: nil, error_code: code, message:)
    end

    def success_result
      Result.new(
        success?: true,
        available_tables: connector.list_tables(include_columns: false),
        checked_at: Time.current,
        error_code: nil,
        message: nil
      )
    end

    def failure_result
      failure(
        code: 'connection_failed',
        message: I18n.t('app.workspaces.data_sources.validation.connection_failed')
      )
    end

    def log_failure(error, level:)
      message = "#{log_prefix(level)}: #{source_type} #{error.class}"
      Rails.logger.public_send(level, message)
    end

    def log_prefix(level)
      return 'Data source connection validation failed' if level == :warn

      'Data source connection validation failed unexpectedly'
    end
  end
end
