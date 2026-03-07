# frozen_string_literal: true

require 'base64'
require 'net/http'

module Chat
  class PlannerService # rubocop:disable Metrics/ClassLength
    Plan = Struct.new(:assistant_message, :action_type, :payload, keyword_init: true)

    ENDPOINT = URI('https://api.openai.com/v1/responses').freeze
    EMAIL_REGEX = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i
    MAX_INLINE_IMAGE_COUNT = 2
    MAX_INLINE_IMAGE_SIZE = 5.megabytes

    def initialize(message:, workspace:, actor:, attachments: [])
      @message = message.to_s.strip
      @workspace = workspace
      @actor = actor
      @attachments = Array(attachments).compact
    end

    def call
      heuristic = heuristic_plan
      return heuristic if heuristic

      llm_plan || default_help_plan
    rescue StandardError => e
      Rails.logger.warn("Chat planner failed, falling back to heuristic planner: #{e.class} #{e.message}")
      heuristic_plan || default_help_plan
    end

    private

    attr_reader :message, :workspace, :actor, :attachments

    def attachment_count
      attachments.size
    end

    def llm_plan # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      return nil if api_key.blank?

      response = http_client.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      json_text = parsed.fetch('output_text', '').to_s
      return nil if json_text.blank?

      planned = JSON.parse(json_text)
      action_type = planned['action_type'].to_s.presence
      payload = planned['payload'].is_a?(Hash) ? planned['payload'] : {}
      assistant_message = planned['assistant_message'].to_s.presence || fallback_assistant_message(action_type:)

      Plan.new(assistant_message:, action_type:, payload:)
    rescue JSON::ParserError
      nil
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
        model: ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini'),
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
                    'If required fields are missing, set action_type to null and ask a concise follow-up question.',
                    'Required fields: workspace.update_name(name), member.invite(email),',
                    'member.resend_invite(email or member_id),',
                    'member.update_role(email or member_id, role),',
                    'member.remove(email or member_id).'
                  ].join(' '),
                  [
                    'For workspace.update_name, payload.name must be a clean target name only,',
                    'without wrapping quotes and without trailing conversational punctuation.'
                  ].join(' '),
                  'Return JSON only with keys assistant_message, action_type, payload.'
                ].join(' ')
              }
            ]
          },
          {
            role: 'user',
            content: user_input_content
          }
        ]
      }
    end

    def user_input_content
      content = [
        {
          type: 'input_text',
          text: [
            "Workspace: #{workspace.id} (#{workspace.name})",
            "Actor: #{actor.id}",
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

      return workspace_delete_plan if lower.match?(/\b(delete|remove)\b.*\bworkspace\b/)
      return workspace_rename_plan if lower.match?(/\b(rename|change)\b.*\bworkspace\b/)
      return member_list_plan if lower.match?(/\b(list|show|who)\b.*\b(team|member)s?\b/)
      return member_resend_plan if lower.match?(/\bresend\b.*\b(invite|invitation)\b/)
      return member_invite_plan if lower.include?('invite')
      return member_role_update_plan if lower.match?(/\b(change|update)\b.*\brole\b/)
      return member_remove_plan if lower.match?(/\b(remove|delete)\b.*\b(member|teammate|team mate|user)\b/)

      if attachment_count.positive?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.attachments_context', count: attachment_count),
          action_type: nil,
          payload: {}
        )
      end

      nil
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
      email = parsed_email
      if email.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_invite_needs_email'),
          action_type: nil,
          payload: {}
        )
      end

      role = parsed_role || Member::Roles::USER

      payload = { 'email' => email, 'role' => role }

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_invite'),
        action_type: 'member.invite',
        payload:
      )
    end

    def member_resend_plan
      email = parsed_email
      if email.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_resend_needs_member'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_resend'),
        action_type: 'member.resend_invite',
        payload: { 'email' => email }
      )
    end

    def member_role_update_plan # rubocop:disable Metrics/MethodLength
      email = parsed_email
      role = parsed_role

      if email.blank? && role.nil?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_role_update_needs_member_and_role'),
          action_type: nil,
          payload: {}
        )
      end
      if email.blank?
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
        payload: {
          'email' => email,
          'role' => role
        }
      )
    end

    def member_remove_plan
      email = parsed_email
      if email.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.member_remove_needs_member'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_remove'),
        action_type: 'member.remove',
        payload: { 'email' => email }
      )
    end

    def parsed_role
      lowered = message.downcase
      return Member::Roles::ADMIN if lowered.include?('admin')
      return Member::Roles::READ_ONLY if lowered.match?(/\b(read[-\s]?only|readonly)\b/)
      return Member::Roles::USER if lowered.include?('user')

      nil
    end

    def parsed_workspace_name
      from_to_match = message.match(/\b(?:rename|change)\b.*\bworkspace\b.*\bto\b\s+(.+)\z/i)
      from_to_name = from_to_match&.captures&.first
      return cleaned_name(from_to_name) if from_to_name.present?

      quoted_match = message.match(/["']([^"']+)["']/)
      cleaned_name(quoted_match&.captures&.first)
    end

    def cleaned_name(value)
      value.to_s.strip.sub(/[.!?]+\z/, '').presence
    end

    def parsed_email
      message[EMAIL_REGEX].to_s.downcase.presence
    end

    def fallback_assistant_message(action_type:)
      return I18n.t('app.workspaces.chat.planner.fallback_with_action') if action_type.present?

      I18n.t('app.workspaces.chat.planner.fallback_without_action')
    end

    def http_client
      Net::HTTP.new(ENDPOINT.host, ENDPOINT.port).tap { |http| http.use_ssl = true }
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end
  end
end
