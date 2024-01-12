# frozen_string_literal: true

# TODO
# - Convert the error messages from ClickHouse to something safe to show
# - Use the views and correct users

class QueryService
  attr_accessor :data, :query, :error, :error_message

  def initialize(query:)
    @query = query
  end

  def execute
    ConnectionHelper.with_database(:clickhouse) do
      @data = ActiveRecord::Base.connection.exec_query(prepared_query)
      self
    end
  rescue ActiveRecord::ActiveRecordError => e
    handle_database_exception(e)
    self
  rescue StandardError => e
    handle_standard_error(e)
    self
  end

  def columns
    @data&.columns.to_a
  end

  def rows
    @data&.rows.to_a
  end

  private

  def prepared_query
    query.query.sub(';', '').squish.downcase
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
    @error_message = 'There was an unkown error'
  end
end
