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
end
