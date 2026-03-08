# frozen_string_literal: true

module OpenaiConfiguration
  DEFAULT_RESPONSES_ENDPOINT = 'https://api.openai.com/v1/responses'

  module_function

  def responses_endpoint
    URI.parse(ENV.fetch('OPENAI_RESPONSES_ENDPOINT', DEFAULT_RESPONSES_ENDPOINT))
  rescue URI::InvalidURIError => e
    Rails.logger.warn("Invalid OPENAI_RESPONSES_ENDPOINT, falling back to default: #{e.message}")
    URI.parse(DEFAULT_RESPONSES_ENDPOINT)
  end
end
