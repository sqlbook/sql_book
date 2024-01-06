# frozen_string_literal: true

class EventChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "Visitor connected #{current_visitor}"
  end

  def unsubscribed
    Rails.logger.info "Visitor disconnected #{current_visitor}"
  end

  def event(data)
    puts session_key, compress_payload(data)
  end

  private

  def session_key
    "events::#{current_visitor}"
  end

  def data_source_uuid
    current_visitor.split('::')[0]
  end

  def visitor_uuid
    current_visitor.split('::')[1]
  end

  def session_uuid
    current_visitor.split('::')[2]
  end
end
