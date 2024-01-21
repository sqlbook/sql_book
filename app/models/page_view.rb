# frozen_string_literal: true

class PageView < EventRecord
  self.table_name = 'page_views'

  def self.nice_name
    'Page Views'
  end
end
