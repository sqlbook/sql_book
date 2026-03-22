# frozen_string_literal: true

module Chat
  class IntentReconciler # rubocop:disable Metrics/ClassLength
    # rubocop:disable Metrics/ParameterLists
    def initialize(
      workspace:,
      actor:,
      chat_thread:,
      source_message:,
      message_text:,
      tool_metadata:,
      context_snapshot:
    )
      @workspace = workspace
      @actor = actor
      @chat_thread = chat_thread
      @source_message = source_message
      @message_text = message_text.to_s
      @tool_metadata = Array(tool_metadata).index_by { |tool| tool[:name] }
      @context_snapshot = context_snapshot
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/AbcSize
    def reconcile(decision:)
      tool_call = decision.tool_calls.first
      tool_definition = tool_metadata[tool_call&.tool_name]

      return non_action_intent(decision:) if decision.finalize_without_tools || tool_call.nil?
      return forbidden_intent(decision:) unless tool_definition

      payload = canonical_payload(action_type: tool_call.tool_name, raw_payload: tool_call.arguments.to_h)
      missing_message = missing_details_message_for(action_type: tool_call.tool_name, payload:)

      if missing_message.present?
        return ActionIntent.new(
          assistant_message: missing_message,
          action_type: nil,
          payload: {},
          missing_information: [missing_message],
          finalize_without_tools: true,
          tool_definition: nil,
          source: 'runtime',
          confidence: 1.0
        )
      end

      ActionIntent.new(
        assistant_message: decision.assistant_message.to_s,
        action_type: tool_call.tool_name,
        payload:,
        missing_information: Array(decision.missing_information),
        finalize_without_tools: false,
        tool_definition:,
        source: 'runtime',
        confidence: 1.0
      )
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :workspace, :actor, :chat_thread, :source_message, :message_text, :tool_metadata, :context_snapshot

    def non_action_intent(decision:)
      ActionIntent.new(
        assistant_message: decision.assistant_message.to_s,
        action_type: nil,
        payload: {},
        missing_information: Array(decision.missing_information),
        finalize_without_tools: true,
        tool_definition: nil,
        source: 'runtime',
        confidence: 1.0
      )
    end

    def forbidden_intent(decision:)
      ActionIntent.new(
        assistant_message: decision.assistant_message.to_s.presence || I18n.t('app.workspaces.chat.executor.forbidden'),
        action_type: nil,
        payload: {},
        missing_information: [],
        finalize_without_tools: true,
        tool_definition: nil,
        source: 'runtime',
        confidence: 1.0
      )
    end

    def canonical_payload(action_type:, raw_payload:)
      payload = raw_payload.to_h.deep_stringify_keys

      apply_workspace_context!(payload:)
      canonical_payload_steps_for(action_type:).each do |step|
        send(step, payload:)
      end

      payload.compact_blank
    end

    def canonical_payload_steps_for(action_type:)
      member_steps = []
      member_steps << :apply_explicit_role! if explicit_role_action?(action_type)
      member_steps << :apply_explicit_member_reference! if explicit_member_reference_action?(action_type)
      member_steps << :apply_context_member_reference! if contextual_member_reference_action?(action_type)

      invite_steps = action_type == 'member.invite' ? [:apply_invite_seed_details!] : []
      query_steps = query_payload_steps_for(action_type:)

      member_steps + invite_steps + query_steps
    end

    def query_payload_steps_for(action_type:)
      return %i[apply_query_question! apply_query_run_refinement_context!] if action_type == 'query.run'
      return %i[apply_recent_query_context! apply_explicit_query_name!] if action_type == 'query.save'
      if action_type == 'query.rename'
        return %i[apply_explicit_query_reference! apply_recent_query_reference! apply_explicit_query_name!]
      end

      if action_type == 'query.update'
        return %i[
          apply_explicit_query_reference!
          apply_recent_query_reference!
          apply_recent_draft_query_context!
          apply_explicit_query_name!
        ]
      end

      return %i[apply_explicit_query_reference! apply_recent_query_reference!] if action_type == 'query.delete'

      []
    end

    def apply_workspace_context!(payload:)
      payload['workspace_id'] = workspace.id
      payload['thread_id'] = chat_thread.id
      payload['message_id'] = source_message.id
    end

    def explicit_role_action?(action_type)
      %w[member.update_role member.invite].include?(action_type)
    end

    def explicit_member_reference_action?(action_type)
      %w[member.update_role member.remove member.resend_invite].include?(action_type)
    end

    def contextual_member_reference_action?(action_type)
      %w[member.update_role member.remove member.resend_invite member.invite].include?(action_type)
    end

    def apply_explicit_role!(payload:)
      explicit_role = RoleParser.parse(text: message_text)
      payload['role'] = explicit_role if explicit_role.present?
    end

    def apply_explicit_member_reference!(payload:)
      explicit_reference = member_reference_resolver.reference_payload(text: message_text)
      payload.merge!(explicit_reference) if explicit_reference.present?
    end

    def apply_context_member_reference!(payload:)
      return unless member_reference_missing?(payload:)
      return if context_snapshot.referenced_member.blank?

      payload.merge!(
        member_reference_resolver.reference_payload(
          payload: context_snapshot.referenced_member
        )
      )
    end

    def apply_invite_seed_details!(payload:)
      return if invite_fields_present?(payload:)

      payload.merge!(context_snapshot.invite_seed_details.to_h)
    end

    def invite_fields_present?(payload)
      payload['email'].present? || payload['first_name'].present? || payload['last_name'].present?
    end

    def member_reference_missing?(payload)
      payload['member_id'].blank? && payload['email'].blank? && payload['full_name'].blank?
    end

    def member_reference_resolver
      @member_reference_resolver ||= MemberReferenceResolver.new(workspace:)
    end

    def apply_query_question!(payload:)
      payload['question'] = payload['question'].to_s.strip.presence || message_text.strip.presence
    end

    def apply_query_run_refinement_context!(payload:)
      return unless query_refinement_request?

      reference = recent_query_refinement_reference
      return if reference.blank?

      payload.merge!(query_run_refinement_attributes(reference:))
    end

    def apply_recent_query_context!(payload:)
      recent_query_reference = context_snapshot.recent_query_reference
      return if recent_query_reference.blank?

      payload['sql'] ||= recent_query_reference['sql']
      payload['question'] ||= recent_query_reference['original_question']
      payload['data_source_id'] ||= recent_query_reference['data_source_id']
      payload['data_source_name'] ||= recent_query_reference['data_source_name']
    end

    def apply_explicit_query_name!(payload:)
      explicit_name = QueryNameParser.parse(text: message_text)
      payload['name'] = explicit_name if explicit_name.present?
    end

    def apply_explicit_query_reference!(payload:)
      explicit_reference = query_reference_resolver.reference_payload(text: message_text)
      payload.merge!(explicit_reference) if explicit_reference.present?
    end

    def apply_recent_draft_query_context!(payload:)
      recent_draft_reference = context_snapshot.recent_draft_query_reference
      return if recent_draft_reference.blank?

      payload['sql'] ||= recent_draft_reference['sql']
      payload['data_source_id'] ||= recent_draft_reference['data_source_id']
      payload['data_source_name'] ||= recent_draft_reference['data_source_name']
    end

    def apply_recent_query_reference!(payload:)
      return if payload['query_id'].present?

      recent_saved_query_reference = context_snapshot.recent_saved_query_reference
      return if recent_saved_query_reference.blank?
      return if recent_saved_query_reference['saved_query_id'].to_s.strip.blank?

      payload['query_id'] = recent_saved_query_reference['saved_query_id']
      payload['query_name'] ||= recent_saved_query_reference['saved_query_name']
    end

    def query_refinement_request?
      message_text.match?(
        /\b(tweak|adjust|update|change|modify|refine|instead|also|split|group|break(?:\s+it)?\s+down|filter)\b/i
      ) || QueryFollowUpMatcher.contextual_follow_up?(
        text: message_text,
        recent_query_reference: recent_query_refinement_reference
      )
    end

    def recent_query_refinement_reference
      reference = context_snapshot.recent_query_reference.to_h.deep_stringify_keys
      return {} if reference.blank? || reference['sql'].to_s.strip.blank?

      reference
    end

    def query_run_refinement_attributes(reference:)
      {}.tap do |attributes|
        attributes['base_sql'] = reference['sql'] if reference['sql'].present?
        attributes['base_question'] = reference['original_question'] if reference['original_question'].present?
        attributes['base_query_name'] = preferred_query_reference_name(reference:)
        attributes['base_saved_query_id'] = reference['saved_query_id'] if reference['saved_query_id'].present?
      end
    end

    def preferred_query_reference_name(reference:)
      reference['saved_query_name'].presence || reference['current_name'].presence
    end

    def query_reference_resolver
      @query_reference_resolver ||= QueryReferenceResolver.new(
        workspace:,
        query_references: context_snapshot.query_references,
        recent_query_state: context_snapshot.recent_query_state,
        conversation_messages: context_snapshot.conversation_messages
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def missing_details_message_for(action_type:, payload:)
      case action_type
      when 'workspace.update_name'
        return I18n.t('app.workspaces.chat.planner.workspace_rename_needs_name') if payload['name'].to_s.strip.blank?
      when 'member.invite'
        missing_fields = []
        missing_fields << 'email' if payload['email'].to_s.strip.blank?
        if payload['first_name'].to_s.strip.blank? || payload['last_name'].to_s.strip.blank?
          missing_fields.push('first_name', 'last_name')
        end
        missing_fields << 'role' if payload['role'].to_s.strip.blank?
        prompt_key = Chat::InvitePromptResolver.key_for(missing_fields:)
        return I18n.t(prompt_key) if prompt_key.present?
      when 'member.resend_invite'
        return I18n.t('app.workspaces.chat.planner.member_resend_needs_member') if member_reference_missing?(payload)
      when 'member.update_role'
        if member_reference_missing?(payload) && payload['role'].to_s.strip.blank?
          return I18n.t('app.workspaces.chat.planner.member_role_update_needs_member_and_role')
        end
        if member_reference_missing?(payload)
          return I18n.t('app.workspaces.chat.planner.member_role_update_needs_member')
        end
        return I18n.t('app.workspaces.chat.planner.member_role_update_needs_role') if payload['role'].to_s.strip.blank?
      when 'member.remove'
        return I18n.t('app.workspaces.chat.planner.member_remove_needs_member') if member_reference_missing?(payload)
      when 'query.save'
        return I18n.t('app.workspaces.chat.planner.query_save_needs_query') if payload['sql'].to_s.strip.blank?
        if payload['data_source_id'].to_s.strip.blank? &&
           payload['data_source_name'].to_s.strip.blank?
          return I18n.t('app.workspaces.chat.query.data_source_not_found')
        end
      when 'query.rename'
        query_id_blank = payload['query_id'].to_s.strip.blank?
        name_blank = payload['name'].to_s.strip.blank?

        return I18n.t('app.workspaces.chat.planner.query_rename_needs_query_and_name') if query_id_blank && name_blank
        return I18n.t('app.workspaces.chat.planner.query_rename_needs_query') if query_id_blank

        if name_blank
          return I18n.t(
            'app.workspaces.chat.planner.query_rename_needs_name',
            query_name: payload['query_name'].to_s.presence || I18n.t('app.workspaces.chat.query_library.this_query')
          )
        end
      when 'query.update'
        query_id_blank = payload['query_id'].to_s.strip.blank?
        sql_blank = payload['sql'].to_s.strip.blank?

        return I18n.t('app.workspaces.chat.planner.query_update_needs_query_and_sql') if query_id_blank && sql_blank
        return I18n.t('app.workspaces.chat.planner.query_update_needs_query') if query_id_blank
        return I18n.t('app.workspaces.chat.planner.query_update_needs_sql') if sql_blank
      when 'query.delete'
        return I18n.t('app.workspaces.chat.planner.query_delete_needs_query') if payload['query_id'].to_s.strip.blank?
      end

      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  end
end
