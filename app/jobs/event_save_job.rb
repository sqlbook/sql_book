# frozen_string_literal: true

class EventSaveJob < ApplicationJob
  def perform(*args)
    args.each do |arg|
      method = :"store_#{arg['type']}"
      send(method, arg) if respond_to?(method, true)
    end
  end

  private

  def store_click(event)
    Click.create(
      data_source_uuid: event['data_source_uuid'],
      session_uuid: event['session_uuid'],
      visitor_uuid: event['visitor_uuid'],
      timestamp: event['timestamp'],
      coordinates_x: event['coordinates_x'],
      coordinates_y: event['coordinates_y'],
      selector: event['selector'],
      inner_text: event['inner_text'],
      attribute_id: event['attribute_id'],
      attribute_class: event['attribute_class']
    )
  end

  def store_page_view(event)
    PageView.create(
      data_source_uuid: event['data_source_uuid'],
      session_uuid: event['session_uuid'],
      visitor_uuid: event['visitor_uuid'],
      timestamp: event['timestamp'],
      url: event['url']
    )
  end

  def store_session(event) # rubocop:disable Metrics/AbcSize
    Session.create(
      data_source_uuid: event['data_source_uuid'],
      session_uuid: event['session_uuid'],
      visitor_uuid: event['visitor_uuid'],
      timestamp: event['timestamp'],
      viewport_x: event['viewport_x'],
      viewport_y: event['viewport_y'],
      device_x: event['device_x'],
      device_y: event['device_y'],
      referrer: event['referrer'],
      locale: event['locale'],
      useragent: event['useragent'],
      browser: UserAgent.parse(event['useragent']).browser,
      timezone: event['timezone'],
      country_code: Rails.configuration.timezones[event['timezone'].to_s],
      utm_source: event['utm_source'],
      utm_medium: event['utm_medium'],
      utm_campaign: event['utm_campaign'],
      utm_content: event['utm_content'],
      utm_term: event['utm_term']
    )
  end
end
