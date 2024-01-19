# frozen_string_literal: true

class Session < ClickHouseRecord
  self.table_name = 'sessions'
  self.primary_key = 'uuid'

  def self.nice_name
    'Sessions'
  end
end
