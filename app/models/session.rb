# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :data_source

  def self.nice_name
    'Sessions'
  end
end
