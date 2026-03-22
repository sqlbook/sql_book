# frozen_string_literal: true

require Rails.root.join('lib/rate_limiting/rack_attack_config')

helper = RateLimiting::RackAttackConfig

Rack::Attack.enabled = helper.enabled_for_environment?
Rack::Attack.cache.store = helper.cache_store

Rack::Attack.throttle(
  'auth/send_code/ip',
  limit: helper.limit_for(:auth_send_code),
  period: helper.period_for(:auth_send_code)
) do |request|
  request.ip if helper.auth_send_code_request?(request)
end

Rack::Attack.throttle(
  'auth/send_code/email',
  limit: helper.limit_for(:auth_send_code),
  period: helper.period_for(:auth_send_code)
) do |request|
  helper.normalized_email(request) if helper.auth_send_code_request?(request)
end

Rack::Attack.throttle(
  'auth/verify/ip',
  limit: helper.limit_for(:auth_verify),
  period: helper.period_for(:auth_verify)
) do |request|
  request.ip if helper.auth_verify_request?(request)
end

Rack::Attack.throttle(
  'auth/verify/email',
  limit: helper.limit_for(:auth_verify),
  period: helper.period_for(:auth_verify)
) do |request|
  helper.normalized_email(request) if helper.auth_verify_request?(request)
end

Rack::Attack.throttle(
  'chat/messages/burst',
  limit: helper.limit_for(:chat_message_burst),
  period: helper.period_for(:chat_message_burst)
) do |request|
  helper.throttle_key(request) if helper.chat_message_request?(request)
end

Rack::Attack.throttle(
  'chat/messages/sustained',
  limit: helper.limit_for(:chat_message_sustained),
  period: helper.period_for(:chat_message_sustained)
) do |request|
  helper.throttle_key(request) if helper.chat_message_request?(request)
end

Rack::Attack.throttle(
  'chat/actions',
  limit: helper.limit_for(:chat_action),
  period: helper.period_for(:chat_action)
) do |request|
  helper.throttle_key(request) if helper.chat_action_request?(request)
end

Rack::Attack.throttle(
  'query/run/burst',
  limit: helper.limit_for(:query_run_burst),
  period: helper.period_for(:query_run_burst)
) do |request|
  helper.throttle_key(request) if helper.query_run_request?(request)
end

Rack::Attack.throttle(
  'query/run/sustained',
  limit: helper.limit_for(:query_run_sustained),
  period: helper.period_for(:query_run_sustained)
) do |request|
  helper.throttle_key(request) if helper.query_run_request?(request)
end

Rack::Attack.throttle(
  'data_source/validate',
  limit: helper.limit_for(:data_source_validate),
  period: helper.period_for(:data_source_validate)
) do |request|
  helper.throttle_key(request) if helper.data_source_validate_request?(request)
end

Rack::Attack.throttle(
  'data_source/create',
  limit: helper.limit_for(:data_source_create),
  period: helper.period_for(:data_source_create)
) do |request|
  helper.throttle_key(request) if helper.data_source_create_request?(request)
end

ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  helper.log_match(request) if request
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data'] || {}
  retry_after = match_data[:period].to_i
  body = {
    status: 'rate_limited',
    error_code: 'rate_limited',
    message: helper.response_message(request),
    retry_after_seconds: retry_after
  }

  if helper.json_request?(request)
    [
      429,
      { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
      [body.to_json]
    ]
  else
    [
      429,
      { 'Content-Type' => 'text/plain; charset=utf-8', 'Retry-After' => retry_after.to_s },
      [body[:message]]
    ]
  end
end
