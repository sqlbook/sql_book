# frozen_string_literal: true

class QueryService
  attr_accessor :data, :query, :error, :error_message

  class NoMatchingModelError < ActiveRecord::ActiveRecordError; end

  def initialize(query:)
    @query = query
    @error = false
  end

  def execute
    as_read_only do
      @data ||= execute_query
      self
    end
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
    data.to_json # TODO: Test this
  end

  private

  def normalized_query
    query.query.squish.downcase
  end

  def handle_database_exception(error)
    # Handle PG::InsufficientPrivilege?
    Rails.logger.warn("Failed to run query - #{error}")
    @error = true
    @error_message = error.message
  end

  def handle_standard_error(error)
    Rails.logger.error("Failed to run query - #{error}")
    @error = true
    @error_message = 'There was an unkown error, please try again'
  end

  def as_read_only(&)
    old_config = EventRecord.connection_db_config.configuration_hash.dup
    new_config = old_config.merge(username: 'sql_book_readonly')

    EventRecord.establish_connection(new_config)
    yield
  ensure
    EventRecord.establish_connection(old_config)
  end

  def execute_query
    EventRecord.transaction do
      EventRecord.connection.exec_query("SET LOCAL app.current_data_source_uuid = '#{query.data_source.external_uuid}'")
      EventRecord.connection.exec_query(normalized_query)
    end
  end
end
