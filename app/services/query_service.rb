# frozen_string_literal: true

# TODO
# - Convert the error messages from ClickHouse to something safe to show
# - Change joined tables to use views

class QueryService
  attr_accessor :data, :query, :error, :error_message

  class NoMatchingModelError < ActiveRecord::ActiveRecordError; end

  def initialize(query:)
    @query = query
    @error = false
  end

  def execute
    @data = ClickHouseRecord.connection.exec_query(prepared_query)
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

  private

  def normalized_query
    query.query.sub(';', '').squish.downcase
  end

  def prepared_query
    ensure_valid_models!

    DataSourcesViewService.new(data_source: query.data_source).replace_table_name(normalized_query)
  end

  def ensure_valid_models!
    return if normalized_query.include?('from clicks')
    return if normalized_query.include?('from sessions')
    return if normalized_query.include?('from page_views')

    handle_model_not_found_error
  end

  # These errors probably don't give away a huge amount, but it
  # would be worth mapping all of the ClickHouse errors to our own
  def handle_database_exception(error)
    Rails.logger.warn("Failed to run query - #{error}")
    @error = true
    @error_message = error.message
  end

  # These errors are very unlikely to be safe for the front end
  def handle_standard_error(error)
    Rails.logger.error("Failed to run query - #{error}")
    @error = true
    @error_message = 'There was an unkown error, please try again'
  end

  def handle_model_not_found_error
    table_name_matcher = /from (\w+)/.match(normalized_query)

    raise NoMatchingModelError, "'#{table_name_matcher[1]}' is not a valid table name" if table_name_matcher

    raise NoMatchingModelError, 'No valid table present in query'
  end
end
