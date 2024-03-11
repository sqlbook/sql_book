# frozen_string_literal: true

class Dashboard < ApplicationRecord
  belongs_to :workspace

  belongs_to :author,
             class_name: 'User',
             primary_key: :id
end
