# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "#{SecureRandom.base36}@email.com" }
    first_name { 'Ray' }
    last_name { 'Manzarek' }
    terms_accepted_at { Time.current }
    terms_version { User::CURRENT_TERMS_VERSION }
  end

  factory :one_time_password do
    email { "#{SecureRandom.base36}@email.com" }
    token { '123456' }
  end

  factory :workspace do
    name { 'The Doors' }

    transient do
      owner { create(:user) }
    end

    factory :workspace_with_owner do
      after(:create) do |workspace, evaluator|
        create(:member, workspace:, user: evaluator.owner)
      end
    end
  end

  factory :member do
    user { create(:user) }
    workspace { create(:workspace) }
    role { Member::Roles::OWNER }
    status { Member::Status::ACCEPTED }
  end

  factory :data_source do
    url { "https://#{SecureRandom.base36}.com" }
    workspace { create(:workspace) }
  end

  factory :dashboard do
    name { 'My dashboard' }
    workspace { create(:workspace) }
  end

  factory :query do
    name { 'My Query' }
    query { 'SELECT * FROM sessions;' }
    saved { false }
    last_run_at { nil }
    data_source { create(:data_source) }
    author { create(:user) }
    last_updated_by { nil }
  end

  factory :chat_thread do
    workspace { create(:workspace) }
    created_by { create(:user) }
    title { 'Workspace chat' }
    archived_at { nil }
  end

  factory :chat_message do
    chat_thread { create(:chat_thread) }
    user { create(:user) }
    role { ChatMessage::Roles::USER }
    status { ChatMessage::Statuses::COMPLETED }
    content { 'Hello there' }
    metadata { {} }
  end

  factory :chat_action_request do
    chat_thread { create(:chat_thread) }
    chat_message { create(:chat_message, chat_thread:) }
    source_message { chat_message }
    requested_by { create(:user) }
    action_type { 'member.invite' }
    status { ChatActionRequest::Statuses::PENDING_CONFIRMATION }
    payload { { 'email' => 'invitee@example.com', 'role' => Member::Roles::USER } }
    result_payload { {} }
    action_fingerprint { SecureRandom.hex(16) }
    idempotency_key { SecureRandom.hex(16) }
    confirmation_token { SecureRandom.hex(20) }
    confirmation_expires_at { 15.minutes.from_now }
  end

  factory :click do
    data_source_uuid { SecureRandom.uuid }
    session_uuid { SecureRandom.uuid }
    visitor_uuid { SecureRandom.uuid }
    timestamp { Time.now.to_i }
    coordinates_x { 1920 }
    coordinates_y { 1080 }
    selector { 'html>body' }
    inner_text { nil }
    attribute_id { nil }
    attribute_class { nil }
  end

  factory :page_view do
    data_source_uuid { SecureRandom.uuid }
    session_uuid { SecureRandom.uuid }
    visitor_uuid { SecureRandom.uuid }
    timestamp { Time.now.to_i }
    url { '/' }
  end

  factory :session do
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
