# frozen_string_literal: true

module ClickHouse
  class ClickHouseRecord < ApplicationRecord
    self.abstract_class = true

    connects_to database: { writing: :clickhouse, reading: :clickhouse }
  end
end
