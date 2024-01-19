# frozen_string_literal: true

class Click < ApplicationRecord
  belongs_to :data_source

  def self.nice_name
    'Clicks'
  end
end
