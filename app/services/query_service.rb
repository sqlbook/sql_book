# frozen_string_literal: true

class QueryService
  EXTERNAL_STATEMENT_TIMEOUT_MS = 5_000
  EXTERNAL_ROW_LIMIT = 1_000

  attr_accessor :data, :query, :error, :error_message

  class NoMatchingModelError < ActiveRecord::ActiveRecordError; end

  def initialize(query:)
    @query = query
    @error = false
  end

  def execute # rubocop:disable Metrics/MethodLength
    @data ||= fetch_query_result
    self
  rescue DataSources::Connectors::BaseConnector::QueryError,
         DataSources::Connectors::BaseConnector::ConnectionError => e
    handle_connector_exception(e)
    self
  rescue ActiveRecord::ActiveRecordError => e
    handle_database_exception(e)
    self
  rescue StandardError => e
    handle_standard_error(e)
    self
  end

  def rows
    data&.rows.to_a
  end

  def columns
    data&.columns.to_a
  end

  def to_json(*)
    data.to_json
  end

  def clear_cache!
    Rails.cache.delete(cache_key)
  end

  private

  def fetch_query_result
    return execute_query unless cache_enabled?

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) { execute_query }
  end

  def cache_key
    [
      'query_results',
      query.id,
      query.data_source.workspace_id,
      query.data_source.id,
      query.data_source.updated_at.to_i
    ].join('::')
  end

  def normalized_query
    query.query.to_s.squish
  end

  def handle_database_exception(error)
    Rails.logger.warn("Failed to run query - #{error.class}")
    @error = true
    @error_message = query_error_message_for(error)
  end

  def handle_connector_exception(error)
    Rails.logger.warn("Failed to run connector query - #{error.class}")
    @error = true
    @error_message = query_error_message_for(error)
  end

  def handle_standard_error(error)
    Rails.logger.error("Failed to run query - #{error.class}")
    @error = true
    @error_message = I18n.t('app.workspaces.data_sources.query_guard.unexpected_error')
  end

  def cache_enabled?
    query.data_source.capture_source?
  end

  def execute_query
    query.data_source.connector.execute_readonly(
      sql: normalized_query,
      statement_timeout_ms: statement_timeout_ms,
      max_rows: max_rows
    )
  end

  def statement_timeout_ms
    return nil if query.data_source.capture_source?

    EXTERNAL_STATEMENT_TIMEOUT_MS
  end

  def max_rows
    return nil if query.data_source.capture_source?

    EXTERNAL_ROW_LIMIT
  end

  def query_error_message_for(error)
    return error.message if query.data_source.capture_source?
    return error.message if error.respond_to?(:code) && error.code.present?

    I18n.t('app.workspaces.data_sources.query_guard.query_failed')
  end
end
