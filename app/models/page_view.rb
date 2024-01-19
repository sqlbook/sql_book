# frozen_string_literal: true

class PageView < ClickHouseRecord
  self.table_name = 'page_views'
  self.primary_key = 'uuid'

  def self.nice_name
    'Page Views'
  end
end
