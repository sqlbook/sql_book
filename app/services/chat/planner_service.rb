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
    DATA_SOURCE_ENTITY_REGEX = /
      \b(
        data\s+source|data\s+sources|datasource|datasources|database|databases|postgres(?:ql)?
      )\b
    /ix
    DATA_SOURCE_LIST_VERB_REGEX = /
      \b(
        list|show|display|get|see|which|what|listar|lista|muestra|mostrar|ver|cu[aá]les
      )\b
    /ix
    QUERY_REQUEST_REGEX = /
      \b(
        how\ many|count|total|average|avg|sum|max|min|show|list|find|get|query|sql|select|with|rows?
      )\b
    /ix
    QUERY_LIBRARY_REGEX = /\b(query\s+library|saved\s+queries|saved\s+query)\b/i
    QUERY_SAVE_REGEX = /
      \b(
        save\s+(?:this|that|the)?\s*query|
        save\s+(?:this|that)\b|
        add\s+(?:this|that|the)?\s*query\s+to\s+(?:the\s+)?query\s+library|
        save\s+it
      )\b
    /ix
    QUERY_RENAME_REGEX = /
      \b(
        rename|retitle
      )\b.*\bquery\b
    /ix
    THREAD_RENAME_REGEX = /
      \b(
        rename|retitle|change|update
      )\b.*\b(
        thread|chat|conversation
      )\b
    /ix
    QUERY_UPDATE_REGEX = /
      \b(
        update|replace|overwrite|edit|modify
      )\b
    /ix
    QUERY_RENAME_CONTEXT_REGEX = /
      \b(
        which\s+saved\s+query\s+to\s+rename|
        rename\s+it\b|
        what\s+would\s+you\s+like\s+to\s+rename|
        i\s+can\s+rename\s+it\s+to\b
      )\b
    /ix
    THREAD_RENAME_CONTEXT_REGEX = /
      \b(
        rename\s+the\s+(?:thread|chat|conversation)(?:\s+title)?\s+to\b|
        update\s+the\s+(?:thread|chat|conversation)(?:\s+title)?\s+to\b|
        update\s+the\s+thread\s+title\s+to\s+match\b
      )\b
    /ix
    RENAME_FOLLOW_UP_CONFIRM_REGEX = /
      \A\s*
      (?:
        oh\s+yeah\s+|
        yeah,\s*
      )?
      (?:
        yes(?:\s+please)?|
        yeah|
        sure|
        go\s+for\s+it|
        please\s+do|
        do\s+it|
        go\s+ahead|
        let'?s\s+do\s+that|
        sounds\s+good
      )\b
    /ix
    QUERY_DELETE_REGEX = /
      \b(
        delete|remove
      )\b.*\bquery\b
    /ix
    QUERY_DATA_HINT_REGEX = /
      \b(
        data\s+source|datasource|database|table|tables|schema|sql|query|queries|row|rows|column|columns
      )\b
    /ix
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
    def initialize(
      message:,
      workspace:,
      actor:,
      attachments: [],
      conversation_messages: [],
      context_snapshot: nil,
      chat_thread_id: nil
    )
      @message = message.to_s.strip
      @workspace = workspace
      @actor = actor
      @attachments = Array(attachments).compact
      @conversation_messages = Array(conversation_messages).compact
      @context_snapshot = context_snapshot
      @chat_thread_id = chat_thread_id.to_i
    end
    # rubocop:enable Metrics/ParameterLists

    def call
      llm_plan || heuristic_plan || default_help_plan
    rescue StandardError => e
      Rails.logger.warn("Chat planner failed, falling back to heuristic planner: #{e.class} #{e.message}")
      heuristic_plan || default_help_plan
    end

    private

    attr_reader :message, :workspace, :actor, :attachments, :conversation_messages, :context_snapshot, :chat_thread_id

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
                    'Your current executable scope in this environment includes workspace management, team management,',
                    'data source management, and read-only data-source querying, using the action contract below.'
                  ].join(' '),
                  'Never propose cross-workspace actions; stay in the current workspace only.',
                  [
                    'In this workspace context, explicit team/member language refers to workspace members,',
                    'but plain "users" may also refer to records inside a data source.'
                  ].join(' '),
                  'Use the recent conversation context to resolve follow-up references like "their names/details".',
                  [
                    [
                      'When Pending follow-up context is present, interpret short ambiguous replies',
                      'against that pending item'
                    ].join(' '),
                    'before falling back to generic capability help.'
                  ].join(' '),
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
                  [
                    'Use structured recent action context for continuity,',
                    'but verify mutable workspace or data-source facts through the live state and tools available.'
                  ].join(' '),
                  'Track the most recent invited, removed, or role-updated member across the thread.',
                  'Classify user intent into an action contract when possible.',
                  [
                    'Allowed actions: workspace.update_name, workspace.delete, member.list, member.invite,',
                    'thread.rename, member.resend_invite, member.update_role, member.remove, datasource.list,',
                    'datasource.validate_connection, datasource.create, query.list, query.run, query.save,',
                    'query.rename, query.update, query.delete.'
                  ].join(' '),
                  [
                    'Disallowed namespaces: workspace.list/get/create, dashboard.*,',
                    'billing.*, subscription.*, admin.*, super_admin.*.'
                  ].join(' '),
                  [
                    'Owners and Admins can manage data sources.',
                    'Owners, Admins, and Users can run read-only data queries.'
                  ].join(' '),
                  [
                    'Before proposing write actions, collect required fields first.',
                    [
                      'If required fields are missing, set action_type to null',
                      'and ask for all currently missing fields in one concise follow-up message.'
                    ].join(' '),
                    'Required fields: workspace.update_name(name), thread.rename(thread_id,title),',
                    'member.invite(first_name,last_name,email,role),',
                    'member.resend_invite(email or member_id or full_name),',
                    'member.update_role(email or member_id or full_name, role),',
                    'member.remove(email or member_id or full_name),',
                    'datasource.validate_connection(host,database_name,username,password),',
                    'datasource.create(name,host,database_name,username,password,selected_tables),',
                    'query.run(question),',
                    'query.save(sql,data_source_id or data_source_name),',
                    'query.rename(query_id,name),',
                    'query.update(query_id,sql,name?),',
                    'query.delete(query_id).'
                  ].join(' '),
                  [
                    'If the user wants to add a PostgreSQL data source,',
                    'ask for missing setup information in sensible chunks',
                    'instead of dumping one giant checklist.'
                  ].join(' '),
                  [
                    'For query-library requests, prefer query.list.',
                    'For "save this query" follow-ups, prefer query.save and reuse the recent executed query context.',
                    'For updating a saved query to match a refined SQL draft, prefer query.update.',
                    'If the user asks to rename the current chat thread, prefer thread.rename.',
                    [
                      'If the user explicitly asks to refine or change the current saved query itself,',
                      'default to updating that query rather than asking update-versus-new',
                      'unless the requested change clearly alters the query purpose.'
                    ].join(' '),
                    'For renaming or deleting saved queries, prefer query.rename or query.delete.',
                    'For data questions, prefer query.run.',
                    'If multiple connected data sources or tables could answer, ask a clarifying question.'
                  ].join(' '),
                  [
                    'Never claim a query-library tool is unavailable',
                    'if it appears in the allowed actions and tool metadata.'
                  ].join(' '),
                  [
                    'Never choose or assume an invite role on the user\'s behalf.',
                    'Ask for the role if it was not explicitly provided.'
                  ].join(' '),
                  [
                    'Do not assume or invent a person\'s gender;',
                    'use neutral phrasing like "them" unless the user provided pronouns.'
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
                    'When you are answering without a tool, or asking for one small clarification,',
                    'you may end with one natural next step that keeps the conversation moving.'
                  ].join(' '),
                  [
                    'Do this sparingly and keep it relevant.',
                    'Avoid repetitive stock sign-offs or tacking on an extra question when the user is clearly done.'
                  ].join(' '),
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

    def conversation_context_line
      Chat::PromptContextFormatter.new(
        context_snapshot:,
        conversation_messages: transcript_messages,
        transcript_limit: 8,
        transcript_character_limit: 280
      ).call
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
      schema_follow_up = schema_summary_follow_up_plan
      return schema_follow_up if schema_follow_up

      role_context_plan = recent_invited_member_role_context_plan
      return role_context_plan if role_context_plan

      recent_member_context_plan = recent_member_context_answer_plan
      return recent_member_context_plan if recent_member_context_plan

      return workspace_delete_plan if lower.match?(/\b(delete|remove)\b.*\bworkspace\b/)
      return workspace_rename_plan if lower.match?(/\b(rename|change)\b.*\bworkspace\b/)
      return thread_rename_plan if thread_rename_intent?(lower)
      return datasource_list_plan if datasource_list_intent?(lower)
      return query_list_plan if query_list_intent?(lower)
      return query_update_plan if query_update_intent?(lower)
      return query_rename_plan if query_rename_intent?(lower)
      return query_delete_plan if query_delete_intent?(lower)
      return member_resend_plan if lower.match?(/\bresend\b.*\b(invite|invitation)\b/)
      return member_invite_plan if member_invite_intent?(lower)
      return member_role_update_plan if lower.match?(/\b(change|update)\b.*\brole\b/)
      return member_role_update_plan if lower.match?(/\b(promote|demote)\b/)
      return member_remove_plan if lower.match?(/\b(remove|delete)\b.*\b(member|teammate|team mate|user)\b/)
      return member_list_plan if member_list_intent?(lower)
      return query_save_plan if query_save_intent?(lower)
      return query_run_plan if query_run_intent?(lower)

      if attachment_count.positive?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.attachments_context', count: attachment_count),
          action_type: nil,
          payload: {}
        )
      end

      nil
    end

    def schema_summary_follow_up_plan
      response = Chat::SchemaSummaryFollowUpResponder.new(
        message:,
        conversation_messages: transcript_messages
      ).call
      return nil if response.blank?

      Plan.new(
        assistant_message: response,
        action_type: nil,
        payload: {}
      )
    end

    def member_list_intent?(lowered_message)
      return true if member_listing_request?(lowered_message)
      return true if member_detail_request_with_member_reference?(lowered_message)

      contextual_member_follow_up?(lowered_message)
    end

    def member_listing_request?(lowered_message)
      lowered_message.match?(MEMBER_ENTITY_REGEX) && lowered_message.match?(MEMBER_LIST_VERB_REGEX)
    end

    def datasource_list_intent?(lowered_message)
      lowered_message.match?(DATA_SOURCE_ENTITY_REGEX) && lowered_message.match?(DATA_SOURCE_LIST_VERB_REGEX)
    end

    def query_list_intent?(lowered_message)
      return false if lowered_message.match?(QUERY_RENAME_REGEX)
      return false if lowered_message.match?(QUERY_DELETE_REGEX)
      return true if lowered_message.match?(QUERY_LIBRARY_REGEX)

      lowered_message.match?(/\b(list|show|display|see|get)\b/) && lowered_message.match?(/\bqueries\b/)
    end

    def query_save_intent?(lowered_message)
      return false if recent_query_reference.blank?

      lowered_message.match?(QUERY_SAVE_REGEX)
    end

    def query_rename_intent?(lowered_message)
      return false if thread_rename_intent?(lowered_message)
      return true if lowered_message.match?(QUERY_RENAME_REGEX)
      return true if rename_follow_up_context_active?

      parsed_query_name.present? && resolved_query_reference_payload['query_id'].present?
    end

    def query_update_intent?(lowered_message)
      return false if recent_draft_query_reference.blank?
      return false unless lowered_message.match?(QUERY_UPDATE_REGEX)

      lowered_message.match?(/\b(query|sql|saved query|existing|current|old|it|that|this)\b/)
    end

    def query_delete_intent?(lowered_message)
      lowered_message.match?(QUERY_DELETE_REGEX)
    end

    def query_run_intent?(lowered_message) # rubocop:disable Metrics/CyclomaticComplexity
      return false if member_list_intent?(lowered_message)
      return false if member_invite_intent?(lowered_message)
      return false if lowered_message.match?(/\b(resend|invite|rename|delete|remove|promote|demote)\b/)
      return true if contextual_query_run_follow_up?
      return true if direct_query_run_intent?(lowered_message)
      return false unless lowered_message.match?(QUERY_REQUEST_REGEX)

      lowered_message.match?(QUERY_DATA_HINT_REGEX) || referenced_data_source_name?(lowered_message)
    end

    def contextual_query_run_follow_up?
      QueryFollowUpMatcher.contextual_follow_up?(
        text: message,
        recent_query_reference:
      )
    end

    def direct_query_run_intent?(lowered_message)
      lowered_message.match?(/\A\s*(select|with)\b/) ||
        lowered_message.match?(/\b(how many|count|total|average|avg|sum|max|min|rows?)\b/)
    end

    def referenced_data_source_name?(lowered_message)
      workspace.data_sources.active.any? do |data_source|
        lowered_message.include?(data_source.display_name.to_s.downcase)
      end
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

    def datasource_list_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.datasource_list'),
        action_type: 'datasource.list',
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

    def query_run_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_run'),
        action_type: 'query.run',
        payload: { 'question' => message }
      )
    end

    def query_list_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_list'),
        action_type: 'query.list',
        payload: {}
      )
    end

    def query_save_plan # rubocop:disable Metrics/AbcSize
      refinement = query_refinement_resolver.resolve
      if refinement.material_drift?
        return Plan.new(
          assistant_message: I18n.t(
            'app.workspaces.chat.planner.query_save_update_or_new',
            current_name: refinement.target_query.name,
            suggested_name: refinement.generated_name.presence || refinement.target_query.name
          ),
          action_type: nil,
          payload: {}
        )
      end

      if refinement.minor_refinement?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.query_update'),
          action_type: 'query.update',
          payload: {
            'query_id' => refinement.target_query.id,
            'query_name' => refinement.target_query.name,
            'sql' => refinement.draft_reference['sql'],
            'name' => parsed_query_name
          }.compact
        )
      end

      payload = {}
      payload['name'] = parsed_query_name if parsed_query_name.present?

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_save'),
        action_type: 'query.save',
        payload:
      )
    end

    def query_update_plan
      payload = resolved_query_reference_payload
      payload['sql'] = recent_draft_query_reference['sql']
      payload['name'] = inferred_query_rename_name if inferred_query_rename_name.present?

      missing_plan = query_update_missing_plan(payload:)
      return missing_plan if missing_plan

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_update'),
        action_type: 'query.update',
        payload:
      )
    end

    def query_rename_plan
      payload = resolved_query_reference_payload
      payload['name'] = inferred_query_rename_name if inferred_query_rename_name.present?

      missing_plan = query_rename_missing_plan(payload:)
      return missing_plan if missing_plan

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_rename'),
        action_type: 'query.rename',
        payload:
      )
    end

    def query_delete_plan
      payload = resolved_query_reference_payload
      if payload['query_id'].blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.query_delete_needs_query'),
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_delete'),
        action_type: 'query.delete',
        payload:
      )
    end

    def thread_rename_plan
      payload = {}
      payload['title'] = inferred_thread_title if inferred_thread_title.present?

      if payload['title'].to_s.strip.blank?
        return Plan.new(
          assistant_message: 'What should I rename this chat to?',
          action_type: nil,
          payload: {}
        )
      end

      Plan.new(
        assistant_message: 'I can rename this chat.',
        action_type: 'thread.rename',
        payload:
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

    def parsed_query_name
      QueryNameParser.parse(text: message)
    end

    def parsed_thread_title
      ThreadTitleParser.parse(text: message)
    end

    def inferred_query_rename_name
      parsed_query_name || recent_requested_query_name || recent_proposed_query_rename_name
    end

    def inferred_thread_title
      parsed_thread_title || recent_proposed_thread_title || recent_matching_thread_title
    end

    def query_rename_missing_plan(payload:)
      return missing_query_and_name_plan if payload['query_id'].blank? && payload['name'].blank?
      return missing_query_plan if payload['query_id'].blank?
      return missing_rename_name_plan(payload:) if payload['name'].blank?

      nil
    end

    def query_update_missing_plan(payload:) # rubocop:disable Metrics/AbcSize
      if payload['query_id'].blank? && payload['sql'].to_s.strip.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.query_update_needs_query_and_sql'),
          action_type: nil,
          payload: {}
        )
      end

      if payload['query_id'].blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.query_update_needs_query'),
          action_type: nil,
          payload: {}
        )
      end

      if payload['sql'].to_s.strip.blank?
        return Plan.new(
          assistant_message: I18n.t('app.workspaces.chat.planner.query_update_needs_sql'),
          action_type: nil,
          payload: {}
        )
      end

      nil
    end

    def missing_query_and_name_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_rename_needs_query_and_name'),
        action_type: nil,
        payload: {}
      )
    end

    def missing_query_plan
      Plan.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_rename_needs_query'),
        action_type: nil,
        payload: {}
      )
    end

    def missing_rename_name_plan(payload:)
      Plan.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.query_rename_needs_name',
          query_name: rename_prompt_query_name(payload:)
        ),
        action_type: nil,
        payload: {}
      )
    end

    def rename_prompt_query_name(payload:)
      payload['query_name'].presence || 'this query'
    end

    def rename_follow_up_context_active?
      return false if inferred_query_rename_name.blank?
      return false unless affirmative_rename_follow_up?

      recent_assistant_content.to_s.match?(QUERY_RENAME_CONTEXT_REGEX) || rename_target_selection_active?
    end

    def thread_rename_intent?(lowered_message)
      lowered_message.match?(THREAD_RENAME_REGEX) || thread_rename_follow_up_context_active?
    end

    def explicit_thread_rename_request?
      message.match?(THREAD_RENAME_REGEX)
    end

    def thread_rename_follow_up_context_active?
      return false if inferred_thread_title.blank?
      return false unless affirmative_rename_follow_up?

      recent_assistant_content.to_s.match?(THREAD_RENAME_CONTEXT_REGEX)
    end

    def affirmative_rename_follow_up?
      message.match?(RENAME_FOLLOW_UP_CONFIRM_REGEX)
    end

    def recent_query_state
      @recent_query_state ||= context_snapshot&.recent_query_state.to_h
    end

    def recent_query_reference
      @recent_query_reference ||= context_snapshot&.recent_query_reference.to_h
    end

    def recent_draft_query_reference
      @recent_draft_query_reference ||= context_snapshot&.recent_draft_query_reference.to_h
    end

    def query_refinement_resolver
      @query_refinement_resolver ||= QueryRefinementResolver.new(
        workspace:,
        context_snapshot:
      )
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
      member = conversation_context_resolver.current_member_for_recent_reference(text: message)
      member ||= current_member_from_recent_context
      return nil unless member
      return nil unless member_context_answerable?(member:)

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

    def member_context_answerable?(member:)
      conversation_context_resolver.member_state_request?(text: message) ||
        (
          member.present? &&
          conversation_context_resolver.member_follow_up_question?(text: message) &&
          recent_member_context_snapshot.present?
        )
    end

    def current_member_from_recent_context # rubocop:disable Metrics/AbcSize
      recent_member = recent_member_context_snapshot
      return nil if recent_member.blank?
      return nil if recent_member['email'].to_s.strip.blank?

      workspace_member = workspace_member_by_email(email: recent_member['email'])
      return nil unless workspace_member

      {
        'member_id' => workspace_member.id,
        'email' => workspace_member.user&.email.to_s,
        'full_name' => workspace_member.user&.full_name.to_s,
        'role_name' => workspace_member.role_name,
        'status_name' => workspace_member.status_name
      }
    end

    def workspace_member_by_email(email:)
      workspace.members
        .includes(:user)
        .joins(:user)
        .find_by(users: { email: email.to_s.downcase })
    end

    def recent_member_context_snapshot
      conversation_context_resolver.recent_member_reference(text: message) ||
        conversation_context_resolver.recent_updated_member ||
        conversation_context_resolver.recent_invited_member ||
        conversation_context_resolver.recent_removed_member
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

    def resolved_query_reference_payload
      explicit_reference = query_reference_resolver.reference_payload(text: message)
      return explicit_reference if explicit_reference['query_id'].present?

      recent_saved_query_reference_payload
    end

    def rename_target_selection_active?
      recent_assistant_content.to_s.match?(/\b(saved\s+queries?|query\s+library)\b/i) &&
        query_reference_resolver.reference_payload(text: message)['query_id'].present?
    end

    def recent_saved_query_reference_payload
      recent_saved_query_reference = context_snapshot&.recent_saved_query_reference.to_h.deep_stringify_keys
      return {} if recent_saved_query_reference.blank?
      return {} if recent_saved_query_reference['saved_query_id'].to_s.strip.blank?

      {
        'query_id' => recent_saved_query_reference['saved_query_id'],
        'query_name' => recent_saved_query_reference['saved_query_name']
      }
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

    def recent_requested_query_name
      recent_user_conversation_texts.each do |text|
        parsed_name = QueryNameParser.parse(text:)
        return parsed_name if parsed_name.present?
      end

      nil
    end

    def recent_proposed_query_rename_name
      QueryNameParser.parse_proposed_rename_name(text: recent_assistant_original_content)
    end

    def recent_proposed_thread_title
      ThreadTitleParser.parse_proposed_title(text: recent_assistant_original_content)
    end

    def recent_matching_thread_title
      return nil unless recent_assistant_content.to_s.match?(THREAD_RENAME_CONTEXT_REGEX)

      recent_saved_query_reference_payload['query_name']
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

    def query_reference_resolver
      @query_reference_resolver ||= Chat::QueryReferenceResolver.new(
        workspace:,
        query_references: context_snapshot&.query_references,
        recent_query_state:,
        conversation_messages: transcript_messages
      )
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

    def recent_assistant_original_content
      recent_assistant_text = conversation_messages.reverse.find do |entry|
        conversation_entry_role(entry) == 'assistant'
      end
      return if recent_assistant_text.blank?

      conversation_entry_content(recent_assistant_text)
    end
  end
end
