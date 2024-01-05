# frozen_string_literal: true

module ClickHouse
  class Session < ClickHouseRecord
    self.table_name = 'sessions'
  end
end
