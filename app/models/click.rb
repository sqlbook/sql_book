# frozen_string_literal: true

class Click < ClickHouseRecord
  self.table_name = 'clicks'

  def self.nice_name
    'Clicks'
  end
end
