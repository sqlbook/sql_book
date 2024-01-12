# frozen_string_literal: true

class ConnectionHelper
  def self.with_database(database)
    previous_connection = database == :clickhouse ? :primary : :clickhouse
    ActiveRecord::Base.establish_connection(database)
    yield
  ensure
    ActiveRecord::Base.establish_connection(previous_connection)
  end
end
