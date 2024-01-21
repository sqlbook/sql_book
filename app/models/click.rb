# frozen_string_literal: true

class Click < EventRecord
  belongs_to :data_source

  self.table_name = 'clicks'

  def self.nice_name
    'Clicks'
  end
end
