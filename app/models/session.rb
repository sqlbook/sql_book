# frozen_string_literal: true

class Session < EventRecord
  belongs_to :data_source

  self.table_name = 'sessions'

  def self.nice_name
    'Sessions'
  end
end
