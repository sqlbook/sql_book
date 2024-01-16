# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "#{SecureRandom.base36}@email.com" }
  end

  factory :one_time_password do
    email { "#{SecureRandom.base36}@email.com" }
    token { '123456' }
  end

  factory :data_source do
    url { "https://#{SecureRandom.base36}.com" }
    user { create(:user) }
  end

  factory :query do
    name { 'My Query' }
    query { 'SELECT * FROM sessions;' }
    saved { false }
    data_source { create(:data_source) }
  end

  factory :click do
    uuid { SecureRandom.uuid }
    data_source_uuid { SecureRandom.uuid }
    session_uuid { SecureRandom.uuid }
    visitor_uuid { SecureRandom.uuid }
    timestamp { Time.now.to_i }
    coordinates_x { 1920 }
    coordinates_y { 1080 }
    xpath { '/html/body' }
    inner_text { nil }
    attribute_id { nil }
    attribute_class { nil }
  end

  factory :page_view do
    uuid { SecureRandom.uuid }
    data_source_uuid { SecureRandom.uuid }
    session_uuid { SecureRandom.uuid }
    visitor_uuid { SecureRandom.uuid }
    timestamp { Time.now.to_i }
    url { '/' }
  end

  factory :session do
    uuid { SecureRandom.uuid }
    data_source_uuid { SecureRandom.uuid }
    session_uuid { SecureRandom.uuid }
    visitor_uuid { SecureRandom.uuid }
    timestamp { Time.now.to_i }
    viewport_x { 1920 }
    viewport_y { 1080 }
    device_x { 1920 }
    device_y { 1080 }
    referrer { nil }
    locale { 'en-GB' }
    useragent { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15' } # rubocop:disable Layout/LineLength
    browser { 'Safari' }
    timezone { 'Europe/London' }
    country_code { 'GB' }
    utm_source { nil }
    utm_medium { nil }
    utm_campaign { nil }
    utm_content { nil }
    utm_term { nil }
  end
end
