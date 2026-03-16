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
      apply_explicit_role!(payload:) if explicit_role_action?(action_type)
      apply_explicit_member_reference!(payload:) if explicit_member_reference_action?(action_type)
      apply_context_member_reference!(payload:) if contextual_member_reference_action?(action_type)
      apply_invite_seed_details!(payload:) if action_type == 'member.invite'

      payload.compact_blank
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
      end

      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  end
end
