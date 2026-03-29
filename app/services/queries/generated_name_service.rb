# frozen_string_literal: true

require 'net/http'

module Queries
  class GeneratedNameService
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end

    def self.generate(**attributes)
      new(**attributes).call
    end

    def self.generate_alternative(**attributes)
      new(**attributes, avoid_existing_names: true).call
    end

    def initialize(existing_names: [], avoid_existing_names: false, **context)
      @sql = context.fetch(:sql).to_s.strip
      @data_source = context[:data_source]
      @existing_names = Array(existing_names).filter_map { |name| name.to_s.strip.presence }
      @avoid_existing_names = avoid_existing_names
      @prompt = Queries::GeneratedNamePrompt.new(
        existing_names: @existing_names,
        avoid_existing_names:,
        **context
      )
    end

    def call
      ensure_configured!
      ensure_query_context!

      parse_response(http_client.request(request))
    end

    private

    attr_reader :sql, :data_source, :existing_names, :avoid_existing_names, :prompt

    def ensure_configured!
      raise ConfigurationError, 'OPENAI_API_KEY is missing' if api_key.blank?
    end

    def ensure_query_context!
      raise RequestError, 'SQL is required for generated query naming' if sql.blank?
      raise RequestError, 'Data source is required for generated query naming' if data_source.blank?
    end

    def request
      req = Net::HTTP::Post.new(endpoint)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = request_payload.to_json
      req
    end

    def request_payload
      {
        model: model_name,
        max_output_tokens: 48,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: prompt.system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: prompt.user_prompt
              }
            ]
          }
        ]
      }
    end

    def http_client
      Net::HTTP.new(endpoint.host, endpoint.port).tap do |http|
        http.use_ssl = endpoint.scheme == 'https'
        http.read_timeout = 8
        http.open_timeout = 3
      end
    end

    def parse_response(response)
      ensure_success_response!(response)

      Queries::GeneratedNameResponseParser.parse!(
        body: response.body,
        allow_existing_names: !avoid_existing_names,
        existing_names:
      )
    end

    def ensure_success_response!(response)
      return if response.is_a?(Net::HTTPSuccess)

      raise RequestError, "OpenAI request failed: #{response.code}"
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def model_name
      ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini')
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end
  end
end
