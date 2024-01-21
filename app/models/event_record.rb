# frozen_string_literal: true

class EventRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :events, reading: :events }

  def self.all_event_types
    [Click, PageView, Session]
  end
end
