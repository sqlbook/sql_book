# frozen_string_literal: true

class Click < ClickHouseRecord
  self.table_name = 'clicks'
  self.primary_key = 'uuid'

  def self.nice_name
    'Clicks'
  end
end
