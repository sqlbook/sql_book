# frozen_string_literal: true

require 'base64'
require 'json'
require 'net/http'

module Chat
  class RuntimeService # rubocop:disable Metrics/ClassLength
    ToolCall = Struct.new(:tool_name, :arguments, keyword_init: true)
    Decision = Struct.new(
      :assistant_message,
      :tool_calls,
      :missing_information,
      :finalize_without_tools,
      keyword_init: true
    )

    MAX_INLINE_IMAGE_COUNT = 2
    MAX_INLINE_IMAGE_SIZE = 5.megabytes
    DECISION_SCHEMA = {
      'type' => 'object',
      'required' => %w[assistant_message tool_calls missing_information finalize_without_tools],
      'additionalProperties' => false,
      'properties' => {
        'assistant_message' => { 'type' => 'string' },
        'tool_calls' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'required' => %w[tool_name arguments],
            'additionalProperties' => false,
            'properties' => {
              'tool_name' => { 'type' => 'string' },
              'arguments' => { 'type' => 'object' }
            }
          }
        },
        'missing_information' => {
          'type' => 'array',
          'items' => { 'type' => 'string' }
        },
        'finalize_without_tools' => { 'type' => 'boolean' }
      }
    }.freeze

    def initialize(message:, workspace:, actor:, tool_metadata:, context: {})
      @message = message.to_s.strip
      @workspace = workspace
      @actor = actor
      @attachments = Array(context[:attachments]).compact
      @conversation_messages = Array(context[:conversation_messages]).compact
      @tool_metadata = Array(tool_metadata).compact
    end

    def call
      decision = llm_decision
      return decision if decision

      fallback_decision
    rescue StandardError => e
      Rails.logger.warn("Chat runtime failed, falling back to planner: #{e.class} #{e.message}")
      fallback_decision
    end

    def compose_tool_result_message(tool_name:, tool_arguments:, execution:)
      return execution.user_message if api_key.blank?

      response = perform_request(payload: tool_result_request_payload(tool_name:, tool_arguments:, execution:))
      return execution.user_message unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      formatted = response_text_from(parsed).to_s.gsub(/\s+/, ' ').strip
      formatted.presence || execution.user_message
    rescue JSON::ParserError
      execution.user_message
    rescue StandardError => e
      Rails.logger.warn("Chat runtime result rendering failed: #{e.class} #{e.message}")
      execution.user_message
    end

    private

    attr_reader :message, :workspace, :actor, :attachments, :conversation_messages, :tool_metadata

    def llm_decision # rubocop:disable Metrics/AbcSize
      return nil if api_key.blank?

      response = perform_request(payload: decision_request_payload)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      response_text = response_text_from(parsed_response)
      return nil if response_text.blank?

      parse_decision_json(response_text)
    rescue JSON::ParserError
      nil
    end

    def parse_decision_json(raw_json) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      parsed = parse_json_object(raw_json)
      return nil unless parsed.is_a?(Hash)

      tool_calls = Array(parsed['tool_calls']).filter_map do |row|
        next unless row.is_a?(Hash)

        tool_name = row['tool_name'].to_s
        arguments = row['arguments'].is_a?(Hash) ? row['arguments'] : {}
        next if tool_name.blank?

        ToolCall.new(tool_name:, arguments:)
      end

      missing_information = Array(parsed['missing_information']).map(&:to_s).map(&:strip).compact_blank

      Decision.new(
        assistant_message: parsed['assistant_message'].to_s,
        tool_calls:,
        missing_information:,
        finalize_without_tools: parsed['finalize_without_tools'] == true
      )
    end

    def fallback_decision # rubocop:disable Metrics/AbcSize
      plan = Chat::PlannerService.new(
        message:,
        workspace:,
        actor:,
        attachments:,
        conversation_messages:
      ).call

      return fallback_message_decision if plan.nil?

      if plan.action_type.present?
        return Decision.new(
          assistant_message: plan.assistant_message.to_s,
          tool_calls: [ToolCall.new(tool_name: plan.action_type, arguments: plan.payload.to_h)],
          missing_information: [],
          finalize_without_tools: false
        )
      end

      Decision.new(
        assistant_message: plan.assistant_message.to_s,
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def fallback_message_decision
      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.default_help'),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def request(payload:)
      req = Net::HTTP::Post.new(endpoint)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = payload.to_json
      req
    end

    def decision_request_payload
      {
        model: ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini'),
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: user_input_content
          }
        ],
        text: decision_format
      }
    end

    def tool_result_request_payload(tool_name:, tool_arguments:, execution:)
      {
        model: ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini'),
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: tool_result_system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: [
                  "User locale: #{actor_locale}",
                  "Workspace: #{workspace.id} (#{workspace.name})",
                  "Original user message: #{message}",
                  "Tool called: #{tool_name}",
                  "Tool arguments: #{tool_arguments.to_json}",
                  "Execution status: #{execution.status}",
                  "Execution data: #{execution.data.to_json}",
                  "Default fallback message: #{execution.user_message}"
                ].join("\n")
              }
            ]
          }
        ]
      }
    end

    def decision_format
      {
        format: {
          type: 'json_schema',
          name: 'chat_runtime_decision',
          schema: DECISION_SCHEMA,
          strict: true
        }
      }
    end

    def system_prompt # rubocop:disable Metrics/MethodLength
      [
        'You are sqlbook\'s workspace chat assistant operating inside one workspace.',
        'Keep the conversation natural and task-focused.',
        "Reply in the user locale: #{actor_locale}.",
        'Prioritize solving the user request over listing capabilities.',
        'Only provide capability summaries when the user explicitly asks what you can do.',
        'When user intent is specific, select a concrete tool call or ask one targeted follow-up.',
        'Use missing_information for required fields that are still absent.',
        'When a user asks to invite someone and no email is present, ask for the email address.',
        'If invite context exists and the user provides an email, use member.invite.',
        'When asked for team member names/details, use member.list and include detailed entries.',
        'Never execute cross-workspace actions.',
        'Never invent permissions or claim execution outside provided tools.',
        'Do not wrap payload values with extra punctuation not intended by user input.',
        'Output strict JSON with keys: assistant_message, tool_calls, missing_information, finalize_without_tools.',
        'tool_calls must be an array of objects: { tool_name, arguments }.',
        'missing_information must be an array of short user-facing prompts.',
        'finalize_without_tools must be true only when no tool should run now.',
        "Available tools metadata:\n#{JSON.pretty_generate(tool_metadata)}"
      ].join(' ')
    end

    def tool_result_system_prompt
      [
        'You are sqlbook\'s workspace chat assistant.',
        'Write the final user-facing response from tool output.',
        'Be clear and concise; do not mention internal tool names.',
        'If data is present, answer directly from that data.',
        'If execution status is not executed, explain what failed and what the user can provide next.',
        'For member list results, include useful member details instead of only counts.',
        "Reply in the user locale: #{actor_locale}."
      ].join(' ')
    end

    def user_input_content
      content = [
        {
          type: 'input_text',
          text: [
            "User locale: #{actor_locale}",
            "Workspace: #{workspace.id} (#{workspace.name})",
            "Actor: #{actor.id}",
            conversation_context_line,
            attachment_context_line,
            "Message: #{message}"
          ].join("\n")
        }
      ]

      content.concat(inline_multimodal_images)
      content
    end

    def conversation_context_line
      return 'Recent conversation: none' if conversation_messages.empty?

      lines = conversation_messages.last(10).map do |entry|
        role = conversation_entry_role(entry)
        content = conversation_entry_content(entry)
        next if role.blank? || content.blank?

        "#{role}: #{content}"
      end.compact

      return 'Recent conversation: none' if lines.empty?

      "Recent conversation:\n#{lines.join("\n")}"
    end

    def attachment_context_line
      return 'Image attachments count: 0' if attachments.empty?

      details = attachments.filter_map do |attachment|
        blob = attachment.blob
        next unless blob

        "#{blob.filename}(#{blob.content_type}, #{blob.byte_size} bytes)"
      end

      "Image attachments count: #{attachments.size} (#{details.join('; ')})"
    end

    def conversation_entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def conversation_entry_content(entry)
      raw = entry[:content].presence || entry['content'].presence || ''
      cleaned = raw.to_s.gsub(/\s+/, ' ').strip
      cleaned[0, 400]
    end

    def inline_multimodal_images
      attachments.filter_map do |attachment|
        blob = attachment.blob
        next unless blob
        next unless ChatMessage::ALLOWED_IMAGE_TYPES.include?(blob.content_type.to_s)
        next if blob.byte_size > MAX_INLINE_IMAGE_SIZE

        {
          type: 'input_image',
          image_url: "data:#{blob.content_type};base64,#{Base64.strict_encode64(attachment.download)}"
        }
      end.first(MAX_INLINE_IMAGE_COUNT)
    rescue StandardError => e
      Rails.logger.warn("Chat runtime skipped multimodal attachment encoding: #{e.class} #{e.message}")
      []
    end

    def perform_request(payload:)
      Net::HTTP.start(
        endpoint.host,
        endpoint.port,
        use_ssl: endpoint.scheme == 'https',
        read_timeout: 18,
        open_timeout: 4
      ) { |http| http.request(request(payload:)) }
    end

    def response_text_from(parsed)
      direct = parsed.fetch('output_text', '').to_s.strip
      return direct if direct.present?

      nested_output_text(parsed)
    end

    def nested_output_text(parsed)
      Array(parsed['output']).flat_map do |output_item|
        Array(output_item['content']).filter_map do |content_item|
          content_text(content_item)
        end
      end.join("\n").strip
    end

    def content_text(content_item)
      raw_text = content_item['text']
      value = raw_text.is_a?(Hash) ? raw_text['value'] : raw_text
      value.to_s.strip.presence
    end

    def parse_json_object(raw_json)
      JSON.parse(raw_json)
    rescue JSON::ParserError
      extracted = extract_json_object(raw_json)
      return nil if extracted.blank?

      JSON.parse(extracted)
    rescue JSON::ParserError
      nil
    end

    def extract_json_object(raw_text)
      fenced = raw_text.match(/```(?:json)?\s*(\{.*\})\s*```/m)
      return fenced[1] if fenced

      first = raw_text.index('{')
      last = raw_text.rindex('}')
      return nil unless first && last && last > first

      raw_text[first..last]
    end

    def actor_locale
      actor.preferred_locale.presence || I18n.default_locale.to_s
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end
  end
end
