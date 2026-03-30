# frozen_string_literal: true

require 'net/http'

module Queries
  class NameReviewService
    def self.review(**attributes)
      new(**attributes).call
    end

    def initialize(current_name:, sql:, data_source:, actor:, question: nil)
      @current_name = current_name.to_s.squish
      @sql = sql.to_s.strip
      @data_source = data_source
      @prompt = Queries::NameReviewPrompt.new(
        current_name:,
        question:,
        sql:,
        data_source:,
        actor:
      )
    end

    def call
      ensure_configured!
      ensure_query_context!

      Queries::NameReviewResponseParser.parse!(body: http_client.request(request).body)
    end

    private

    attr_reader :current_name, :sql, :data_source, :prompt

    def ensure_configured!
      raise Queries::GeneratedNameService::ConfigurationError, 'OPENAI_API_KEY is missing' if api_key.blank?
    end

    def ensure_query_context!
      if current_name.blank?
        raise Queries::GeneratedNameService::RequestError, 'Current query name is required for name review'
      end

      raise Queries::GeneratedNameService::RequestError, 'SQL is required for name review' if sql.blank?
      raise Queries::GeneratedNameService::RequestError, 'Data source is required for name review' if data_source.blank?
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
        max_output_tokens: 120,
        input: [
          {
            role: 'system',
            content: [{ type: 'input_text', text: prompt.system_prompt }]
          },
          {
            role: 'user',
            content: [{ type: 'input_text', text: prompt.user_prompt }]
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
