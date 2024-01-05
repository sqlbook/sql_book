# frozen_string_literal: true

module ClickHouse
  class PageView < ClickHouseRecord
    self.table_name = 'page_views'
  end
end
