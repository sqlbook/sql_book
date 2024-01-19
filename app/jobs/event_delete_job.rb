# frozen_string_literal: true

class EventDeleteJob < ApplicationJob
  def perform(*args)
    Event::ALL_EVENT_TYPES.each do |model|
      model.where(data_source_uuid: args.first).destroy_all
    end
  end
end
