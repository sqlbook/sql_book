# frozen_string_literal: true

require 'net/http'

module Translations
  class OpenaiTranslationService
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end

    ENDPOINT = URI('https://api.openai.com/v1/responses').freeze

    def initialize(source_text:, source_locale:, target_locale:, translation_key:)
      @source_text = source_text
      @source_locale = source_locale
      @target_locale = target_locale
      @translation_key = translation_key
    end

    def call
      ensure_configured!
      parse_response(http_client.request(request))
    rescue JSON::ParserError => e
      raise RequestError, "Invalid OpenAI response format: #{e.message}"
    end

    private

    attr_reader :source_text, :source_locale, :target_locale, :translation_key

    def ensure_configured!
      raise ConfigurationError, 'OPENAI_API_KEY is missing' if api_key.blank?
    end

    def request
      req = Net::HTTP::Post.new(ENDPOINT)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = request_payload.to_json
      req
    end

    def request_payload
      {
        model: model_name,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: [
                  'You are a translation assistant.',
                  'Keep tone neutral and reasonably friendly.',
                  'Preserve placeholder tokens exactly and do not add commentary.'
                ].join(' ')
              }
            ]
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: [
                  "Translate from #{source_locale} to #{target_locale}.",
                  "Key: #{translation_key.key}",
                  "Area tags: #{translation_key.area_tags.join(', ')}",
                  "Type tags: #{translation_key.type_tags.join(', ')}",
                  "Text: #{source_text}"
                ].join("\n")
              }
            ]
          }
        ]
      }
    end

    def http_client
      Net::HTTP.new(ENDPOINT.host, ENDPOINT.port).tap { |http| http.use_ssl = true }
    end

    def parse_response(response)
      ensure_success_response!(response)

      text = JSON.parse(response.body).fetch('output_text', '').to_s.strip
      raise RequestError, 'OpenAI response was empty' if text.blank?

      text
    end

    def ensure_success_response!(response)
      return if response.is_a?(Net::HTTPSuccess)

      raise RequestError, "OpenAI request failed: #{response.code}"
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def model_name
      ENV.fetch('OPENAI_TRANSLATIONS_MODEL', 'gpt-4.1-mini')
    end
  end
end
