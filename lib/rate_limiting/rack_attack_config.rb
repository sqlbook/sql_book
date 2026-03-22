# frozen_string_literal: true

module RateLimiting
  module RackAttackConfig
    LIMITS = {
      auth_send_code: { limit: 5, period: 15.minutes },
      auth_verify: { limit: 10, period: 10.minutes },
      chat_message_burst: { limit: 5, period: 30.seconds },
      chat_message_sustained: { limit: 20, period: 5.minutes },
      chat_action: { limit: 30, period: 5.minutes },
      query_run_burst: { limit: 5, period: 30.seconds },
      query_run_sustained: { limit: 20, period: 5.minutes },
      data_source_validate: { limit: 10, period: 10.minutes },
      data_source_create: { limit: 10, period: 30.minutes }
    }.freeze

    module_function

    def enabled_for_environment?
      !Rails.env.test? || ENV['ENABLE_RATE_LIMITING_IN_TESTS'] == '1'
    end

    def cache_store
      @cache_store ||= Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache
    end

    def limit_for(key)
      LIMITS.fetch(key).fetch(:limit)
    end

    def period_for(key)
      LIMITS.fetch(key).fetch(:period)
    end

    def throttle_key(request)
      user_id = session_user_id(request)
      user_id.present? ? "user:#{user_id}" : "ip:#{request.ip}"
    end

    def session_user_id(request)
      request.session[:current_user_id].presence || request.session['current_user_id'].presence
    rescue StandardError
      nil
    end

    def normalized_email(request)
      request.params['email'].to_s.strip.downcase.presence
    rescue StandardError
      nil
    end

    def auth_send_code_request?(request)
      request.get? && request.path.in?(%w[/auth/login/new /auth/login/resend /auth/signup/new /auth/signup/resend])
    end

    def auth_verify_request?(request)
      (request.post? && request.path.in?(%w[/auth/login /auth/signup])) ||
        (request.get? && request.path.in?(%w[/auth/login/magic_link /auth/signup/magic_link]))
    end

    def chat_message_request?(request)
      request.post? && request.path.match?(%r{\A/app/workspaces/\d+/chat/messages\z})
    end

    def chat_action_request?(request)
      request.post? && request.path.match?(%r{\A/app/workspaces/\d+/chat/actions/\d+/(confirm|cancel)\z})
    end

    def query_run_request?(request)
      request.post? && request.path.match?(%r{\A/api/v1/workspaces/\d+/queries/run\z})
    end

    def data_source_validate_request?(request)
      request.post? && request.path.match?(
        %r{
          \A(?:/api/v1/workspaces/\d+/data-sources/validate-connection|
          /app/workspaces/\d+/data_sources/validate_connection)\z
        }x
      )
    end

    def data_source_create_request?(request)
      request.post? && request.path.match?(
        %r{\A(?:/api/v1/workspaces/\d+/data-sources|/app/workspaces/\d+/data_sources)\z}
      )
    end

    def response_category(request)
      match_name = request.env['rack.attack.matched'].to_s
      return 'auth' if match_name.start_with?('auth/')
      return 'chat' if match_name.start_with?('chat/')
      return 'query' if match_name.start_with?('query/')
      return 'data_source' if match_name.start_with?('data_source/')

      'generic'
    end

    def json_request?(request)
      request.path.start_with?('/api/') ||
        request.path.include?('/chat/messages') ||
        request.path.include?('/chat/actions/')
    end

    def response_message(request)
      locale = request.get_header('HTTP_ACCEPT_LANGUAGE').to_s.downcase.start_with?('es') ? :es : :en
      I18n.t("rate_limits.messages.#{response_category(request)}", locale:)
    end

    def log_match(request)
      Rails.logger.info(
        [
          'Rack::Attack throttle hit',
          "name=#{request.env['rack.attack.matched']}",
          "path=#{request.path}",
          "ip=#{request.ip}",
          "user_id=#{session_user_id(request) || 'anonymous'}"
        ].join(' ')
      )
    end
  end
end
