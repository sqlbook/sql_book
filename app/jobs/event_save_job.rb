# frozen_string_literal: true

class EventSaveJob < ApplicationJob
  def perform(*args)
    puts args
  end
end
