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

    trait :postgres do
      source_type { :postgres }
      status { :active }
      name { 'Warehouse DB' }
      url { nil }
      config do
        {
          'host' => 'db.internal',
          'port' => 5432,
          'database_name' => 'warehouse',
          'username' => 'readonly',
          'ssl_mode' => 'prefer',
          'extract_category_values' => false,
          'selected_tables' => ['public.orders', 'public.customers']
        }
      end
      after(:build) do |data_source|
        data_source.connection_password ||= 'super-secret'
      end
    end
  end

  factory :dashboard do
    name { 'My dashboard' }
    workspace { create(:workspace) }
  end

  factory :visualization_theme do
    workspace { create(:workspace) }
    name { 'Editorial Contrast' }
    theme_json_dark do
      {
        'color' => %w[#F5807B #5CA1F2 #F8BD77],
        'backgroundColor' => '#1C1C1C',
        'textStyle' => { 'color' => '#ECEAE6' }
      }
    end
    theme_json_light do
      {
        'color' => %w[#FF6A64 #3E86D9 #D88B39],
        'backgroundColor' => '#F4F2EE',
        'textStyle' => { 'color' => '#111111' }
      }
    end
    default { false }
  end

  factory :query do
    name { 'My Query' }
    sequence(:query) { |n| "SELECT * FROM sessions /* factory_query_#{n} */;" }
    saved { false }
    last_run_at { nil }
    data_source { create(:data_source) }
    author { create(:user) }
    last_updated_by { nil }
  end

  factory :query_visualization do
    query { create(:query) }
    chart_type { 'line' }
    theme_reference { Visualizations::SystemTheme::REFERENCE_KEY }
    data_config do
      {
        'dimension_key' => 'label',
        'value_key' => 'value',
        'table_page_size' => 10
      }
    end
    appearance_config_dark { {} }
    appearance_config_light { {} }
    other_config do
      {
        'title' => nil,
        'subtitle' => nil,
        'title_enabled' => false,
        'subtitle_enabled' => false,
        'legend_enabled' => false,
        'tooltip_enabled' => true,
        'x_axis_label' => 'Label',
        'x_axis_label_enabled' => true,
        'y_axis_label' => 'Value',
        'y_axis_label_enabled' => true
      }
    end
  end

  factory :query_group do
    workspace { create(:workspace) }
    sequence(:name) { |n| "Query Group #{n}" }
  end

  factory :query_group_membership do
    query { create(:query) }
    query_group { create(:query_group, workspace: query.data_source.workspace) }
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

  factory :chat_query_reference do
    chat_thread { create(:chat_thread) }
    source_message { nil }
    result_message { nil }
    data_source { create(:data_source, workspace: chat_thread.workspace) }
    saved_query { nil }
    original_question { 'How many users do I have?' }
    sql { 'SELECT COUNT(*) AS user_count FROM public.users' }
    current_name { 'User count' }
    name_aliases { [] }
    row_count { 1 }
    columns { ['user_count'] }
  end

  factory :chat_pending_follow_up do
    workspace { create(:workspace) }
    chat_thread { create(:chat_thread, workspace:) }
    created_by { create(:user) }
    source_message { nil }
    status { ChatPendingFollowUp::Statuses::ACTIVE }
    kind { 'query_rename_suggestion' }
    domain { 'query' }
    target_type { 'saved_query' }
    target_id { 123 }
    payload do
      {
        'current_name' => '5 longest standing users',
        'suggested_name' => '10 longest standing users'
      }
    end
    resolved_at { nil }
    superseded_at { nil }
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
