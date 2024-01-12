# frozen_string_literal: true

class ClickHouseRecord < ApplicationRecord
  self.abstract_class = true

  establish_connection :clickhouse
end
