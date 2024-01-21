# frozen_string_literal: true

class PageView < EventRecord
  belongs_to :data_source

  self.table_name = 'page_views'

  def self.nice_name
    'Page Views'
  end
end
