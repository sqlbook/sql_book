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
    EMAIL_REGEX = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i
    CHAT_MODEL_FALLBACK = 'gpt-4.1-mini'
    NAME_WITH_EMAIL_REGEX = /
      \b([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)
      (?:
        \s*[,;:]\s* |
        \s*[,;:]?\s+(?:whose\s+)?(?:e-?mail|correo)(?:\s+(?:address|electr[oó]nico))?\s*(?:is|es)?\s+ |
        \s+
      )
      #{EMAIL_REGEX.source}\b
    /ix
    INVITE_CONTEXT_REGEX = /\b(invitation|invite|invitar|invitacion|correo|email)\b/i
    INVITE_INTENT_REGEX = /\b(invite|invitar|invitaci[oó]n)\b/i
    PLACEHOLDER_NAME_PARTS = %w[
      someone somebody anyone anybody person people team teammate teammates mate mates
      member members user users my our else another one this that
    ].freeze
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
      decision = apply_deterministic_guards(decision)
      return decision if decision

      fallback_decision
    rescue StandardError => e
      Rails.logger.warn("Chat runtime failed, falling back to planner: #{e.class} #{e.message}")
      fallback_decision
    end

    def compose_tool_result_message(tool_name:, tool_arguments:, execution:)
      return execution.user_message if api_key.blank?

      rendered = render_tool_result_with_models(
        tool_name:,
        tool_arguments:,
        execution:
      )
      rendered.presence || execution.user_message
    rescue StandardError => e
      Rails.logger.warn("Chat runtime result rendering failed: #{e.class} #{e.message}")
      execution.user_message
    end

    private

    attr_reader :message, :workspace, :actor, :attachments, :conversation_messages, :tool_metadata

    def llm_decision
      return nil if api_key.blank?

      decision_from_models
    end

    def decision_from_models
      chat_model_candidates.each do |model|
        decision = decision_for_model(model:)
        return decision if decision
      end

      nil
    end

    def decision_for_model(model:)
      response = decision_response_for(model:)
      return nil unless response

      decision_from_response_body(response_body: response.body)
    rescue JSON::ParserError => e
      Rails.logger.warn("Chat runtime decision parse failed (model=#{model}): #{e.class} #{e.message}")
      nil
    end

    def render_tool_result_with_models(tool_name:, tool_arguments:, execution:)
      chat_model_candidates.each do |model|
        rendered = rendered_tool_result_for_model(
          model:,
          tool_name:,
          tool_arguments:,
          execution:
        )
        return rendered if rendered.present?
      end

      nil
    end

    def parse_decision_json(raw_json)
      parsed = parse_json_object(raw_json)
      return nil unless parsed.is_a?(Hash)

      Decision.new(
        assistant_message: parsed['assistant_message'].to_s,
        tool_calls: build_tool_calls(parsed:),
        missing_information: build_missing_information(parsed:),
        finalize_without_tools: parsed['finalize_without_tools'] == true
      )
    end

    def fallback_decision
      return planner_fallback_decision if api_key.blank?

      fallback_message_decision
    end

    def fallback_message_decision
      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.messages.runtime_retry'),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def planner_fallback_decision # rubocop:disable Metrics/AbcSize
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

    def decision_response_for(model:)
      response = perform_request(payload: decision_request_payload(model:))
      return response if response.is_a?(Net::HTTPSuccess)

      log_response_failure(context: 'decision', model:, response:)
      nil
    end

    def decision_from_response_body(response_body:)
      parsed_response = JSON.parse(response_body)
      response_text = response_text_from(parsed_response)
      return nil if response_text.blank?

      parse_decision_json(response_text) || non_structured_decision(response_text:)
    end

    def non_structured_decision(response_text:)
      cleaned = response_text.to_s.gsub(/\s+/, ' ').strip
      return nil if cleaned.blank?
      return nil if cleaned.start_with?('{', '[')

      Decision.new(
        assistant_message: cleaned,
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def rendered_tool_result_for_model(model:, tool_name:, tool_arguments:, execution:)
      response = tool_result_response_for(
        model:,
        tool_name:,
        tool_arguments:,
        execution:
      )
      return nil unless response

      parsed_tool_result_message(
        response_body: response.body,
        fallback_message: execution.user_message
      )
    rescue JSON::ParserError => e
      Rails.logger.warn("Chat runtime tool result parse failed (model=#{model}): #{e.class} #{e.message}")
      nil
    end

    def tool_result_response_for(model:, tool_name:, tool_arguments:, execution:)
      response = perform_request(
        payload: tool_result_request_payload(
          model:,
          tool_name:,
          tool_arguments:,
          execution:
        )
      )
      return response if response.is_a?(Net::HTTPSuccess)

      log_response_failure(context: 'tool_result', model:, response:)
      nil
    end

    def request(payload:)
      req = Net::HTTP::Post.new(endpoint)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = payload.to_json
      req
    end

    def decision_request_payload(model:)
      {
        model:,
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

    def tool_result_request_payload(model:, tool_name:, tool_arguments:, execution:)
      {
        model:,
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

    def system_prompt
      [
        'You are sqlbook\'s workspace chat assistant operating inside one workspace.',
        'Keep the conversation natural and task-focused.',
        "Reply in the user locale: #{actor_locale}.",
        'In this workspace context, user/member/team member refer to workspace members.',
        'Prioritize solving the user request over listing capabilities.',
        'Only provide capability summaries when the user explicitly asks what you can do.',
        'Use tool metadata schemas as your source of truth for required fields and argument shapes.',
        'Extract required fields directly from natural-language user messages whenever possible.',
        'If the user provides first name, last name, and email in one message, prepare member.invite immediately.',
        'Treat "users" as workspace team members in this context.',
        'For "who are my users/members/team members" requests, call member.list.',
        'When user intent is specific, select a concrete tool call or ask one targeted follow-up.',
        'Use missing_information for required fields that are still absent.',
        'For member.invite, required fields are first_name, last_name, and email.',
        'If invite context exists, collect missing invite fields and continue until all required fields are present.',
        'Do not fall back to a generic capability summary during invite follow-ups.',
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

    def parsed_tool_result_message(response_body:, fallback_message:)
      parsed = JSON.parse(response_body)
      formatted = response_text_from(parsed).to_s.gsub(/\s+/, ' ').strip
      formatted.presence || fallback_message
    rescue JSON::ParserError
      fallback_message
    end

    def build_tool_calls(parsed:)
      Array(parsed['tool_calls']).filter_map do |row|
        next unless row.is_a?(Hash)

        tool_name = row['tool_name'].to_s
        arguments = row['arguments'].is_a?(Hash) ? row['arguments'] : {}
        next if tool_name.blank?

        ToolCall.new(tool_name:, arguments:)
      end
    end

    def build_missing_information(parsed:)
      Array(parsed['missing_information']).map(&:to_s).map(&:strip).compact_blank
    end

    def parse_json_object(raw_json)
      JSON.parse(raw_json)
    rescue JSON::ParserError
      parse_extracted_json(raw_json:)
    end

    def extract_json_object(raw_text)
      fenced = raw_text.match(/```(?:json)?\s*(\{.*\})\s*```/m)
      return fenced[1] if fenced

      first = raw_text.index('{')
      last = raw_text.rindex('}')
      return nil unless first && last && last > first

      raw_text[first..last]
    end

    def parse_extracted_json(raw_json:)
      extracted = extract_json_object(raw_json)
      return nil if extracted.blank?

      JSON.parse(extracted)
    rescue JSON::ParserError
      nil
    end

    def actor_locale
      actor.preferred_locale.presence || I18n.default_locale.to_s
    end

    def apply_deterministic_guards(decision)
      return decision if decision.nil?
      return decision unless no_tool_selected?(decision)
      return decision unless invite_context_active?

      invite_details = inferred_invite_details
      missing_fields = missing_invite_fields(invite_details:)
      return invite_follow_up_decision(invite_details:) if missing_fields.empty?

      invite_missing_details_decision(missing_fields:)
    end

    def no_tool_selected?(decision)
      decision.tool_calls.empty?
    end

    def invite_context_active?
      message.match?(INVITE_INTENT_REGEX) ||
        invite_context_in_recent_messages?
    end

    def invite_context_in_recent_messages?
      recent_assistant_message = conversation_messages.reverse.find do |entry|
        conversation_entry_role(entry) == 'assistant'
      end
      return false unless recent_assistant_message

      conversation_entry_content(recent_assistant_message).match?(INVITE_CONTEXT_REGEX)
    end

    def inferred_invite_details
      details = invite_details_from_recent_user_messages
      details['email'] = parsed_email if parsed_email.present?
      details.merge(parsed_name_payload)
    end

    def invite_details_from_recent_user_messages # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      details = {}
      conversation_messages.reverse.each do |entry|
        next unless conversation_entry_role(entry) == 'user'

        text = conversation_entry_content(entry)
        details['email'] ||= parse_email_from(text:)
        parsed_name = parsed_name_payload_from(text:)
        details['first_name'] ||= parsed_name['first_name']
        details['last_name'] ||= parsed_name['last_name']
        break if missing_invite_fields(invite_details: details).empty?
      end

      details
    end

    def missing_invite_fields(invite_details:)
      fields = []
      fields << 'email' if invite_details['email'].to_s.strip.blank?
      fields << 'first_name' if invite_details['first_name'].to_s.strip.blank?
      fields << 'last_name' if invite_details['last_name'].to_s.strip.blank?
      fields
    end

    def invite_follow_up_decision(invite_details:)
      payload = {
        'email' => invite_details['email'],
        'first_name' => invite_details['first_name'],
        'last_name' => invite_details['last_name'],
        'role' => Member::Roles::USER
      }

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_invite'),
        tool_calls: [ToolCall.new(tool_name: 'member.invite', arguments: payload)],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def invite_missing_details_decision(missing_fields:)
      prompt = invite_missing_details_prompt(missing_fields:)
      Decision.new(
        assistant_message: prompt,
        tool_calls: [],
        missing_information: [prompt],
        finalize_without_tools: true
      )
    end

    def invite_missing_details_prompt(missing_fields:)
      return I18n.t('app.workspaces.chat.planner.member_invite_needs_email') if missing_fields == ['email']
      if missing_fields.intersect?(%w[first_name last_name]) && missing_fields.exclude?('email')
        return I18n.t('app.workspaces.chat.planner.member_invite_needs_name')
      end

      I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name')
    end

    def parsed_email
      parse_email_from(text: message)
    end

    def parsed_name_payload
      parsed_name_payload_from(text: message)
    end

    def parse_email_from(text:)
      text[EMAIL_REGEX].to_s.downcase.presence
    end

    def parsed_name_payload_from(text:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      match = text.match(
        /\b(?:name\s+is|called|se\s+llama)\s+([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)/i
      )
      if match
        payload = normalized_name_payload(match)
        return payload if valid_name_payload?(payload)
      end

      invite_name_match = text.match(
        /\b(?:invite|invitar)\s+([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)/i
      )
      if invite_name_match
        payload = normalized_name_payload(invite_name_match)
        return payload if valid_name_payload?(payload)
      end

      name_before_email_match = text.match(NAME_WITH_EMAIL_REGEX)
      if name_before_email_match
        payload = normalized_name_payload(name_before_email_match)
        return payload if valid_name_payload?(payload)
      end

      simple_name_match = text.strip.match(/\A([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)\z/i)
      return {} unless simple_name_match

      payload = normalized_name_payload(simple_name_match)
      return {} unless valid_name_payload?(payload)

      payload
    end

    def normalized_name_payload(match_data)
      {
        'first_name' => normalize_name_part(match_data[1]),
        'last_name' => normalize_name_part(match_data[2])
      }
    end

    def normalize_name_part(value)
      value.to_s.strip.split(/\s+/).map(&:capitalize).join(' ')
    end

    def valid_name_payload?(payload)
      first = payload['first_name'].to_s.downcase
      last = payload['last_name'].to_s.downcase
      return false if first.blank? || last.blank?
      return false if PLACEHOLDER_NAME_PARTS.include?(first)
      return false if PLACEHOLDER_NAME_PARTS.include?(last)

      true
    end

    def chat_model_candidates
      configured_model = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini').to_s.strip
      candidates = [configured_model.presence || 'gpt-5-mini']
      candidates << CHAT_MODEL_FALLBACK unless candidates.include?(CHAT_MODEL_FALLBACK)
      candidates
    end

    def log_response_failure(context:, model:, response:)
      body = response.body.to_s.gsub(/\s+/, ' ').strip
      preview = body[0, 220]
      Rails.logger.warn(
        "Chat runtime #{context} response failed (model=#{model}): " \
        "status=#{response.code} body=#{preview}"
      )
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end
  end
end
