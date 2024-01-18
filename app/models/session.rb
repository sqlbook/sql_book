# frozen_string_literal: true

class Session < ClickHouseRecord
  self.table_name = 'sessions'

  def self.nice_name
    'Sessions'
  end
end
