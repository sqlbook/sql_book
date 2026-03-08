# frozen_string_literal: true

require 'net/http'

module Chat
  class ThreadTitleService
    MAX_TITLE_LENGTH = 80

    def initialize(message:, workspace:, actor:)
      @message = message.to_s.squish
      @workspace = workspace
      @actor = actor
    end

    def call
      title = llm_title || heuristic_title

      sanitize_title(title).presence || I18n.t('app.workspaces.chat.threads.untitled')
    rescue StandardError => e
      Rails.logger.warn("Chat thread title generation failed: #{e.class} #{e.message}")
      heuristic_title.presence || I18n.t('app.workspaces.chat.threads.untitled')
    end

    private

    attr_reader :message, :workspace, :actor

    def llm_title
      return nil if api_key.blank?
      return nil if message.blank?

      response = llm_response
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      parsed.fetch('output_text', '').to_s.squish.presence
    rescue JSON::ParserError
      nil
    end

    def llm_response
      Net::HTTP.start(
        endpoint.host,
        endpoint.port,
        use_ssl: endpoint.scheme == 'https',
        read_timeout: 8,
        open_timeout: 3
      ) { |http| http.request(request) }
    end

    def heuristic_title
      return nil if message.blank?

      candidate = message
        .sub(/\A(?:can you|could you|please)\s+/i, '')
        .sub(/[.!?]+\z/, '')

      candidate.truncate(MAX_TITLE_LENGTH, separator: ' ', omission: '...')
    end

    def sanitize_title(value)
      value.to_s
        .squish
        .gsub(/\A["']+|["']+\z/, '')
        .sub(/[.!?]+\z/, '')
        .truncate(MAX_TITLE_LENGTH, separator: ' ', omission: '...')
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
        model: ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini'),
        max_output_tokens: 32,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: [
                  'Generate a short chat title from the user message.',
                  'Return only the title text.',
                  'Use the same language as the user.',
                  'Keep it between 2 and 7 words.',
                  'Do not use quotes.',
                  'Do not end with punctuation.'
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
                  "Workspace: #{workspace.id} (#{workspace.name})",
                  "Actor: #{actor.id}",
                  "Message: #{message}"
                ].join("\n")
              }
            ]
          }
        ]
      }
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end
  end
end
