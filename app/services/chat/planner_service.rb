# frozen_string_literal: true

require 'base64'
require 'net/http'

module Chat
  class PlannerService # rubocop:disable Metrics/ClassLength
    Plan = Struct.new(:assistant_message, :action_type, :payload, keyword_init: true)

    EMAIL_REGEX = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i
    NAME_WITH_EMAIL_REGEX = /
      \b([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)
      (?:
        \s*[,;:]\s* |
        \s*[,;:]?\s+(?:whose\s+)?(?:e-?mail|correo)(?:\s+(?:address|electr[oó]nico))?\s*(?:is|es)?\s+ |
        \s+
      )
      #{EMAIL_REGEX.source}\b
    /ix
    MEMBER_ENTITY_REGEX = /\b(team|teammates?|team mates?|member|members|equipo|miembro|miembros)\b/
    MEMBER_LIST_VERB_REGEX = /\b(list|show|display|get|see|who|listar|lista|muestra|mostrar|ver|quien|quienes)\b/
    INVITE_CONTEXT_REGEX = /
      \b(
        invitation|invite|invitar|invitacion|correo|email
      )\b
    /x
    INVITE_INTENT_REGEX = /\b(invite|invitar|invitaci[oó]n)\b/i
    MEMBER_DETAIL_REGEX = /
      \b(
        name|names|email|emails|detail|details|their|who\ are\ they|
        nombre|nombres|correo|correos|detalle|detalles|quienes\ son
      )\b
    /x
    MEMBER_CONTEXT_REGEX = /
      \b(
        team\ members?|member\ list|found\s+\d+\s+team\ members?|workspace\ team|
        miembros?(?:\s+del\s+equipo)?|se\ encontraron\s+\d+\s+miembros?
      )\b
    /x
    MAX_INLINE_IMAGE_COUNT = 2
    MAX_INLINE_IMAGE_SIZE = 5.megabytes
    PLACEHOLDER_NAME_PARTS = %w[
      someone somebody anyone anybody person people team teammate teammates mate mates
      member members user users my our else another one this that
    ].freeze
    CHAT_MODEL_FALLBACK = 'gpt-4.1-mini'
    PLAN_SCHEMA = {
      'type' => 'object',
      'required' => %w[assistant_message action_type payload],
      'additionalProperties' => false,
      'properties' => {
        'assistant_message' => { 'type' => 'string' },
        'action_type' => { 'type' => %w[string null] },
        'payload' => { 'type' => 'string' }
      }
    }.freeze

    # rubocop:disable Metrics/ParameterLists
    def initialize(message:, workspace:, actor:, attachments: [], conversation_messages: [], context_snapshot: nil)
      @message = message.to_s.strip
      @workspace = workspace
      @actor = actor
      @attachments = Array(attachments).compact
      @conversation_messages = Array(conversation_messages).compact
      @context_snapshot = context_snapshot
    end
    # rubocop:enable Metrics/ParameterLists

    def call
      llm_plan || heuristic_plan || default_help_plan
    rescue StandardError => e
      Rails.logger.warn("Chat planner failed, falling back to heuristic planner: #{e.class} #{e.message}")
      heuristic_plan || default_help_plan
    end

    private

    attr_reader :message, :workspace, :actor, :attachments, :conversation_messages, :context_snapshot

    def attachment_count
      attachments.size
    end

    def llm_plan
      return nil if api_key.blank?

      chat_model_candidates.each do |model|
        plan = llm_plan_for_model(model:)
        return plan if plan
      end

      nil
    rescue StandardError => e
      Rails.logger.warn("Chat planner request failed: #{e.class} #{e.message}")
      nil
    end

    def llm_plan_for_model(model:)
      response = planner_response_for(model:)
      return nil unless response

      planned = planner_payload_from_response(response_body: response.body, model:)
      return nil unless planned.is_a?(Hash)

      build_plan_from_llm_payload(planned:)
    end

    def build_plan_from_llm_payload(planned:)
      action_type = planned['action_type'].to_s.presence
      payload = parsed_payload(planned['payload'])
      assistant_message = planned['assistant_message'].to_s.presence || fallback_assistant_message(action_type:)

      Plan.new(assistant_message:, action_type:, payload:)
    end

    def parsed_payload(raw_payload)
      return raw_payload if raw_payload.is_a?(Hash)

      parse_json_object(raw_payload.to_s).presence || {}
    end

    def request(payload:)
      req = Net::HTTP::Post.new(endpoint)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = payload.to_json
      req
    end

    def request_payload(model:) # rubocop:disable Metrics/AbcSize
      {
        model:,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: [
                  'You are sqlbook\'s in-workspace chat assistant.',
                  [
                    'sqlbook is a collaborative data workspace product. Teams can manage workspace settings,',
                    'team members, data sources, queries, and dashboards.'
                  ].join(' '),
                  [
                    'Your current executable scope in this environment is workspace/team management only,',
                    'using the action contract below.'
                  ].join(' '),
                  [
                    'Future capabilities may include datasource/query/dashboard actions, but those are not',
                    'available to execute right now. If asked, explain this clearly and offer supported actions.'
                  ].join(' '),
                  'Never claim to have executed actions that are out of scope.',
                  'Never propose cross-workspace actions; stay in the current workspace only.',
                  'In this workspace context, user/member/team member refer to workspace members.',
                  'Use the recent conversation context to resolve follow-up references like "their names/details".',
                  [
                    'When the user asks for team members, `member.list` means detailed member output',
                    '(name, email, role, status), not only a count.'
                  ].join(' '),
                  [
                    'Team member visibility is role-scoped.',
                    [
                      'If the actor lacks permission to view the team list,',
                      'explain that an Admin or Workspace owner can help.'
                    ].join(' ')
                  ].join(' '),
                  [
                    'If the user asks a follow-up after a member list response (for example names, emails,',
                    'details, "who are they"), respond with `member.list` again instead of a capability summary.'
                  ].join(' '),
                  'Do not fall back to generic capability lists for specific follow-up questions.',
                  [
                    'Only provide a capability summary when the user explicitly asks a meta question like',
                    '"what can you do?".'
                  ].join(' '),
                  'Use structured recent action context as authoritative when it is provided.',
                  'Track the most recent invited, removed, or role-updated member across the thread.',
                  'Classify user intent into an action contract when possible.',
                  [
                    'Allowed actions: workspace.update_name, workspace.delete, member.list, member.invite,',
                    'member.resend_invite, member.update_role, member.remove.'
                  ].join(' '),
                  [
                    'Disallowed namespaces: workspace.list/get/create, datasource.*, query.*, dashboard.*,',
                    'billing.*, subscription.*, admin.*, super_admin.*.'
                  ].join(' '),
                  [
                    'Before proposing write actions, collect required fields first.',
                    [
                      'If required fields are missing, set action_type to null',
                      'and ask for all currently missing fields in one concise follow-up message.'
                    ].join(' '),
                    'Required fields: workspace.update_name(name), member.invite(first_name,last_name,email,role),',
                    'member.resend_invite(email or member_id or full_name),',
                    'member.update_role(email or member_id or full_name, role),',
                    'member.remove(email or member_id or full_name).'
                  ].join(' '),
                  [
                    'Never choose or assume an invite role on the user\'s behalf.',
                    'Ask for the role if it was not explicitly provided.'
                  ].join(' '),
                  [
                    'If the user says "invite them back" or similar, reuse the recent member identity',
                    'if available, but still ask for role unless the user explicitly gave one.'
                  ].join(' '),
                  [
                    'If the user asks what role a recently invited member was added as,',
                    'answer from the recent structured invite result.'
                  ].join(' '),
                  'Treat natural role replies like "I think admin" or "make them admin" as explicit role instructions.',
                  'Avoid repeating the same filler opening like "Sure." in consecutive replies.',
                  [
                    'For workspace.update_name, payload.name must be a clean target name only,',
                    'without wrapping quotes and without trailing conversational punctuation.'
                  ].join(' '),
                  'Return JSON only with keys assistant_message, action_type, payload.',
                  'payload must be a JSON string encoding an object, for example "{}" or "{\"name\":\"New name\"}".'
                ].join(' ')
              }
            ]
          },
          {
            role: 'user',
            content: user_input_content
          }
        ],
        text: plan_format
      }
    end

    def user_input_content
      content = [
        {
          type: 'input_text',
          text: [
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

    def attachment_context_line
      return 'Image attachments count: 0' if attachment_count.zero?

      details = attachments.filter_map do |attachment|
        blob = attachment.blob
        next unless blob

        "#{blob.filename}(#{blob.content_type}, #{blob.byte_size} bytes)"
      end

      "Image attachments count: #{attachment_count} (#{details.join('; ')})"
    end

    def conversation_context_line # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      lines = transcript_messages.last(8).map do |entry|
        role = conversation_entry_role(entry)
        content = conversation_entry_content(entry)
        next if role.blank? || content.blank?

        "#{role}: #{content}"
      end.compact

      structured_lines = if context_snapshot.present?
                           Array(context_snapshot.structured_context_lines)
                         else
                           conversation_context_resolver.structured_context_lines
                         end
      return 'Recent conversation: none' if lines.empty? && structured_lines.empty?

      parts = []
      parts << "Recent conversation:\n#{lines.join("\n")}" if lines.any?
      parts << "Recent structured context:\n#{structured_lines.join("\n")}" if structured_lines.any?
      parts.join("\n")
    end

    def conversation_entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def conversation_entry_content(entry)
      raw = entry[:content].presence || entry['content'].presence || ''
      cleaned = raw.to_s.gsub(/\s+/, ' ').strip
      cleaned[0, 280]
    end

    def transcript_messages
      return context_snapshot.conversation_messages if context_snapshot.present?

      conversation_messages
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
      Rails.logger.warn("Chat planner skipped multimodal attachment encoding: #{e.class} #{e.message}")
      []
    end

    def heuristic_plan # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return default_help_plan if message.blank? && attachment_count.zero?

      lower = message.downcase

      recent_member_context_plan = recent_member_context_answer_plan
      return recent_member_context_plan if recent_member_context_plan

      role_context_plan = recent_invited_member_role_context_plan
      return role_context_plan if role_context_plan

      return workspace_delete_plan if lower.match?(/\b(delete|remove)\b.*\bworkspace\b/)
      return workspace_rename_plan if lower.match?(/\b(rename|change)\b.*\bworkspace\b/)
      return member_resend_plan if lower.match?(/\bresend\b.*\b(invite|invitation)\b/)
      return member_invite_plan if member_invite_intent?(lower)
      return member_role_update_plan if lower.match?(/\b(change|update)\b.*\brole\b/)
      return member_role_update_plan if lower.match?(/\b(promote|demote)\b/)
      return member_remove_plan if lower.match?(/\b(remove|delete)\b.*\b(member|teammate|team mate|user)\b/)
      return member_list_plan if member_list_intent?(lower)

      if attachment_count.positive?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.attachments_context', count: attachment_count),
          action_type: nil,
          payload: {}
        )
      end

      nil
    end

    def member_list_intent?(lowered_message)
      return true if member_listing_request?(lowered_message)
      return true if member_detail_request_with_member_reference?(lowered_message)

      contextual_member_follow_up?(lowered_message)
    end

    def member_listing_request?(lowered_message)
      lowered_message.match?(MEMBER_ENTITY_REGEX) && lowered_message.match?(MEMBER_LIST_VERB_REGEX)
    end

    def member_invite_intent?(lowered_message)
      return true if lowered_message.match?(INVITE_INTENT_REGEX)

      invite_follow_up_with_email? || invite_follow_up_with_name? || invite_follow_up_with_role?
    end

    def invite_follow_up_with_email?
      parsed_email.present? && invite_follow_up_context?
    end

    def invite_follow_up_with_name?
      parsed_name_payload.present? && invite_follow_up_context?
    end

    def invite_follow_up_with_role?
      parsed_role.present? && invite_follow_up_context?
    end

    def member_detail_request_with_member_reference?(lowered_message)
      lowered_message.match?(MEMBER_ENTITY_REGEX) && lowered_message.match?(MEMBER_DETAIL_REGEX)
    end

    def contextual_member_follow_up?(lowered_message)
      return false unless lowered_message.match?(MEMBER_DETAIL_REGEX)
      return false if invite_follow_up_with_email?

      recent_text = transcript_messages.last(8).map { |entry| conversation_entry_content(entry).downcase }.join(' ')
      recent_text.match?(MEMBER_CONTEXT_REGEX)
    end

    def default_help_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.default_help'),
        action_type: nil,
        payload: {}
      )
    end

    def workspace_delete_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.workspace_delete'),
        action_type: 'workspace.delete',
        payload: {}
      )
    end

    def workspace_rename_plan
      name = parsed_workspace_name
      if name.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.workspace_rename_needs_name'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.workspace_rename'),
        action_type: 'workspace.update_name',
        payload: { 'name' => name }
      )
    end

    def member_list_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_list'),
        action_type: 'member.list',
        payload: {}
      )
    end

    def member_invite_plan
      details = invite_details
      missing_fields = missing_invite_fields(details:)
      if missing_fields.any?
        return Plan.new(
          assistant_message: invite_missing_details_message(missing_fields:),
          action_type: nil,
          payload: {}
        )
      end

      payload = {
        'email' => details['email'],
        'first_name' => details['first_name'],
        'last_name' => details['last_name'],
        'role' => details['role']
      }

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_invite'),
        action_type: 'member.invite',
        payload:
      )
    end

    def member_resend_plan
      member_reference = resolved_member_reference_payload
      if member_reference.empty?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_resend_needs_member'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_resend'),
        action_type: 'member.resend_invite',
        payload: member_reference
      )
    end

    def member_role_update_plan # rubocop:disable Metrics/MethodLength
      member_reference = resolved_member_reference_payload
      role = parsed_role

      if member_reference.empty? && role.nil?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_role_update_needs_member_and_role'),
          action_type: nil,
          payload: {}
        )
      end
      if member_reference.empty?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_role_update_needs_member'),
          action_type: nil,
          payload: {}
        )
      end
      if role.nil?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_role_update_needs_role'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_role_update'),
        action_type: 'member.update_role',
        payload: member_reference.merge('role' => role)
      )
    end

    def member_remove_plan
      member_reference = resolved_member_reference_payload
      if member_reference.empty?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_remove_needs_member'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_remove'),
        action_type: 'member.remove',
        payload: member_reference
      )
    end

    def parsed_role
      parsed_role_from(text: message)
    end

    def parsed_role_from(text:)
      Chat::RoleParser.parse(text:)
    end

    def parsed_workspace_name
      from_to_match = message.match(/\b(?:rename|change)\b.*\bworkspace\b.*\bto\b\s+(.+)\z/i)
      from_to_name = from_to_match&.captures&.first
      return cleaned_name(from_to_name) if from_to_name.present?

      quoted_match = message.match(/["']([^"']+)["']/)
      cleaned_name(quoted_match&.captures&.first)
    end

    def recent_invited_member_role_context_plan
      return nil unless conversation_context_resolver.role_question_context_active?(text: message)

      invited_member = conversation_context_resolver.recent_invited_member_for_role_question(text: message)
      return nil unless invited_member

      Plan.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.member_invite_role_answer',
          name: invited_member['full_name'].presence || invited_member['email'],
          role: invited_member['role_name'],
          status: invited_member['status_name']
        ),
        action_type: nil,
        payload: {}
      )
    end

    def recent_member_context_answer_plan
      return nil unless recent_member_context_question?

      member = conversation_context_resolver.current_member_for_recent_reference(text: message)
      return nil unless member

      Plan.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.member_recent_reference_answer',
          name: member['full_name'].presence || member['email'],
          email: member['email'],
          role: member['role_name'],
          status: member['status_name']
        ),
        action_type: nil,
        payload: {}
      )
    end

    def recent_member_context_question?
      conversation_context_resolver.identity_question?(text: message) ||
        conversation_context_resolver.status_question?(text: message) ||
        conversation_context_resolver.clarification_question?(text: message)
    end

    def cleaned_name(value)
      value.to_s.strip.sub(/[.!?]+\z/, '').presence
    end

    def parsed_email
      parse_email_from(text: message)
    end

    def resolved_member_reference_payload
      resolved_reference = member_reference_resolver.reference_payload(text: message)
      return resolved_reference if resolved_reference.present?
      if (context_member = conversation_context_resolver.recent_member_reference(text: message))
        return context_member.slice('member_id', 'email', 'full_name').compact_blank
      end

      parsed_email.present? ? { 'email' => parsed_email } : {}
    end

    def invite_details
      details = conversation_context_resolver.invite_seed_details(text: message)
        .slice('email', 'first_name', 'last_name')
        .merge(invite_details_from_recent_user_messages)
      details['email'] = parsed_email if parsed_email.present?
      details.merge!(parsed_name_payload)
      details['role'] ||= parsed_role
      details
    end

    def invite_details_from_recent_user_messages
      details = {}
      recent_user_conversation_texts.each do |text|
        merge_recent_invite_details!(details:, text:)
        break if invite_details_complete?(details:)
      end

      details
    end

    def invite_follow_up_context?
      recent_assistant_text = recent_assistant_content
      return false if recent_assistant_text.blank?

      recent_assistant_text.match?(INVITE_CONTEXT_REGEX) ||
        invite_follow_up_prompts.include?(recent_assistant_text)
    end

    def parse_email_from(text:)
      text[EMAIL_REGEX].to_s.downcase.presence
    end

    def parsed_name_payload
      parsed_name_payload_from(text: message)
    end

    def parsed_name_payload_from(text:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      match = text.match(
        /\b(?:name\s+is|called|se\s+llama)\s+([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)/i
      )
      if match
        payload = normalized_name_payload(match)
        return payload if valid_name_payload?(payload)
      end

      return {} if text.match?(/\b(?:invite|invitar)\s+(?:him|her|them)\b/i)

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

    def missing_invite_fields(details:) # rubocop:disable Metrics/AbcSize
      fields = []
      fields << 'email' if details['email'].to_s.strip.blank?
      fields << 'first_name' if details['first_name'].to_s.strip.blank?
      fields << 'last_name' if details['last_name'].to_s.strip.blank?
      fields << 'role' if details['role'].to_s.strip.blank?
      fields
    end

    def invite_missing_details_message(missing_fields:)
      prompt_key = Chat::InvitePromptResolver.key_for(missing_fields:)
      I18n.t(prompt_key)
    end

    def recent_user_conversation_texts
      conversation_messages.reverse_each.filter_map do |entry|
        conversation_entry_content(entry) if conversation_entry_role(entry) == 'user'
      end
    end

    def merge_recent_invite_details!(details:, text:)
      invite_details_from_text(text:).each do |key, value|
        details[key] ||= value
      end
    end

    def invite_details_from_text(text:)
      parsed_name = parsed_name_payload_from(text:)

      {
        'email' => parse_email_from(text:),
        'first_name' => parsed_name['first_name'],
        'last_name' => parsed_name['last_name'],
        'role' => parsed_role_from(text:)
      }.compact_blank
    end

    def invite_details_complete?(details:)
      missing_invite_fields(details:).empty?
    end

    def invite_follow_up_prompts
      @invite_follow_up_prompts ||= %w[
        member_invite_needs_role
        member_invite_needs_name
        member_invite_needs_email
        member_invite_needs_email_and_role
        member_invite_needs_name_and_role
        member_invite_needs_email_and_name
        member_invite_needs_email_name_and_role
      ].map { |key| I18n.t("app.workspaces.chat.planner.#{key}").downcase }
    end

    def fallback_assistant_message(action_type:)
      return I18n.t('app.workspaces.chat.planner.fallback_with_action') if action_type.present?

      I18n.t('app.workspaces.chat.planner.fallback_without_action')
    end

    def plan_format
      {
        format: {
          type: 'json_schema',
          name: 'chat_planner_plan',
          schema: PLAN_SCHEMA,
          strict: true
        }
      }
    end

    def response_text_from(parsed)
      direct = parsed.fetch('output_text', '').to_s.strip
      return direct if direct.present?

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
      parse_extracted_json(raw_json:)
    end

    def extract_json_object(raw_text)
      text = raw_text.to_s
      start_idx = text.index('{')
      end_idx = text.rindex('}')
      return nil unless start_idx && end_idx && end_idx > start_idx

      text[start_idx..end_idx]
    end

    def parse_extracted_json(raw_json:)
      extracted = extract_json_object(raw_json)
      return nil if extracted.blank?

      JSON.parse(extracted)
    rescue JSON::ParserError
      nil
    end

    def planner_response_for(model:)
      response = http_client.request(request(payload: request_payload(model:)))
      return response if response.is_a?(Net::HTTPSuccess)

      log_response_failure(context: 'planner', model:, response:)
      nil
    end

    def planner_payload_from_response(response_body:, model:)
      parsed = JSON.parse(response_body)
      json_text = response_text_from(parsed)
      return nil if json_text.blank?

      parse_json_object(json_text)
    rescue JSON::ParserError => e
      Rails.logger.warn("Chat planner JSON parse failed (model=#{model}): #{e.class} #{e.message}")
      nil
    end

    def log_response_failure(context:, model:, response:)
      body = response.body.to_s.gsub(/\s+/, ' ').strip
      preview = body[0, 220]
      Rails.logger.warn("Chat #{context} response failed (model=#{model}): status=#{response.code} body=#{preview}")
    end

    def chat_model_candidates
      configured_model = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini').to_s.strip
      candidates = [configured_model.presence || 'gpt-5-mini']
      candidates << CHAT_MODEL_FALLBACK unless candidates.include?(CHAT_MODEL_FALLBACK)
      candidates
    end

    def http_client
      Net::HTTP.new(endpoint.host, endpoint.port).tap { |http| http.use_ssl = endpoint.scheme == 'https' }
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def member_reference_resolver
      @member_reference_resolver ||= Chat::MemberReferenceResolver.new(workspace:)
    end

    def conversation_context_resolver
      @conversation_context_resolver ||= Chat::ConversationContextResolver.new(
        workspace:,
        conversation_messages: transcript_messages
      )
    end

    def recent_assistant_content
      recent_assistant_text = conversation_messages.reverse.find do |entry|
        conversation_entry_role(entry) == 'assistant'
      end
      return if recent_assistant_text.blank?

      conversation_entry_content(recent_assistant_text).downcase
    end
  end
end
