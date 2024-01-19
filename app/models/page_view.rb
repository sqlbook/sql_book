# frozen_string_literal: true

class PageView < ApplicationRecord
  belongs_to :data_source

  def self.nice_name
    'Page Views'
  end
end
