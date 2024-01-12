# frozen_string_literal: true

class EventChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "Visitor connected #{current_visitor}"
  end

  def unsubscribed
    Rails.logger.info "Visitor disconnected #{current_visitor}"
  end

  def event(data)
    EventSaveJob.perform_later(data)
  end
end
