# frozen_string_literal: true

module ClickHouse
  class ClickHouseRecord < ApplicationRecord
    self.abstract_class = true

    establish_connection :clickhouse
  end
end
