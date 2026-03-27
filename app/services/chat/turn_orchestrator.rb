# frozen_string_literal: true

module Chat
  class TurnOrchestrator # rubocop:disable Metrics/ClassLength
    CONFIRM_MESSAGE_REGEX = /
      \A\s*(?:i\s+confirm|confirm|yes(?:\s+please)?|go\s+ahead|do\s+it|proceed|continue|si|sí)\b
    /ix
    CANCEL_MESSAGE_REGEX = /\A\s*(?:cancel|stop|never\s+mind|do\s+not|don't|no)\b/i
    CAPABILITY_QUESTION_REGEX = /
      \b(
        what\ can\ you\ do|what\ do\ you\ do|how\ can\ you\ help|
        what\ can\ you\ help\ with|what\ are\ you\ able\ to\ do
      )\b
    /ix
    GENERAL_QUESTION_REGEX = /\A\s*(?:what|when|where|who|why|how|do|does|did|can|could|would|is|are|tell)\b/i
    IN_SCOPE_TOPIC_REGEX = /
      \b(
        workspace|team|teammate|member|members|user|users|
        invite|invitation|role|roles|admin|owner|read\s*only|readonly|
        save|saved|rename|update|replace|overwrite|edit|modify|delete|remove|resend|promote|demote|
        data\s+source|data\s+sources|datasource|datasources|database|databases|
        query|queries|sql|schema|table|tables|row|rows|column|columns
      )\b
    /ix
    PRODUCT_TOPIC_REGEX = /\b(analytics|analysis|data\s+sources?|queries?|dashboards?|charts?|reports?|sql)\b/i
    QUERY_LIKE_REGEX = /
      \b(
        how\ many|count|total|average|avg|sum|max|min|show|list|find|get|query|sql|select|with|who|rows?
      )\b
    /ix
    QUERY_CLARIFICATION_HINT_REGEX = /\b(first|second|third|last|that one|this one|those)\b/i
    QUERY_SCOPE_ASSISTANT_REGEX = /
      \bworkspace(?:\s+team)?\s+members?\b.*\b(connected(?:\s+app)?\s+database|data\s+source|database\ records?)\b|
      \b(connected(?:\s+app)?\s+database|data\s+source|database\ records?)\b.*\bworkspace(?:\s+team)?\s+members?\b
    /ixm
    QUERY_CLARIFICATION_FOLLOW_UP_REGEX = /
      \b(
        connected|database|data\s+source|datasource|schema|table|tables|column|columns|record|records
      )\b
    /ix
    QUERY_DATABASE_ENTITY_FOLLOW_UP_REGEX = /\b(users?|records?)\b/i
    QUERY_SCOPE_AMBIGUOUS_USERS_REGEX = /\busers?\b/i
    QUERY_SCOPE_TEAM_HINT_REGEX = /\b(team|workspace\s+members?|member|members)\b/i
    QUERY_SCOPE_DATABASE_HINT_REGEX = /\b(connected|database|data\s+source|datasource|records?|app\s+database)\b/i
    QUERY_SCOPE_TEAM_FOLLOW_UP_REGEX = /\b(team|my\s+team|workspace\s+team|workspace\s+members?|team\s+members?)\b/i
    CONNECTED_DATA_SOURCE_REFERENCE_REGEX = /
      \b(
        connected(?:\s+app)?\s+database|
        connected\s+data\s+source|
        already\s+connected|
        already\s+have|
        existing\s+data\s+source|
        query\s+the\s+one|
        use\s+the\s+connected
      )\b
    /ix
    QUERY_SAVE_KEEP_NAME_REGEX = /
      \b(
        keep|use|save
      )\b.*\b(
        that|same|the
      )?\s*name\b|
      \bthat\s+name\s+is\s+fine\b|
      \bsave\s+it\s+anyway\b
    /ix

    # rubocop:disable Metrics/ParameterLists
    def initialize(workspace:, chat_thread:, actor:, user_message:, content:, tool_metadata: nil)
      @workspace = workspace
      @chat_thread = chat_thread
      @actor = actor
      @user_message = user_message
      @content = content.to_s
      @tool_metadata = tool_metadata || Tooling::WorkspaceRegistry.tool_metadata
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def call
      @context_snapshot = build_context_snapshot

      if active_pending_action.present? && pending_action_command.present?
        return pending_action_command == :confirm ? confirm_pending_action : cancel_pending_action
      end

      if should_resume_query_clarification?
        return execute_direct_tool(action_type: 'query.run', payload: { 'question' => content })
      end

      if should_resume_recent_query_scope_clarification?
        return execute_direct_tool(action_type: 'query.run', payload: { 'question' => resumed_query_scope_question })
      end
      if should_resume_recent_team_scope_clarification?
        return execute_direct_tool(action_type: 'member.list', payload: {})
      end

      if (save_name_conflict_resolution = query_save_name_conflict_resolution)
        return handle_query_save_name_conflict_resolution(save_name_conflict_resolution)
      end

      if recent_query_follow_up_request?
        return execute_direct_tool(action_type: 'query.run', payload: recent_query_follow_up_payload)
      end
      return execute_direct_tool(action_type: 'query.run', payload: { 'question' => content }) if direct_sql_request?

      if (setup_resolution = data_source_setup_resolution)
        return handle_data_source_setup_resolution(setup_resolution)
      end

      if (schema_summary_follow_up = schema_summary_follow_up_response)
        return render_non_action(schema_summary_follow_up)
      end

      return render_non_action(capability_summary_message) if capability_question?
      return render_non_action(scope_limited_message) if off_scope_general_question?
      return render_non_action(query_scope_clarification_message) if initial_query_scope_clarification_needed?

      decision = runtime_service.call
      intent = intent_reconciler.reconcile(decision:)
      if intent.finalize_without_tools || intent.action_type.blank?
        return render_non_action(intent.assistant_message.presence || intent.missing_information.join(' '))
      end
      return render_non_action(intent.assistant_message) if intent.missing?

      preflight_result = action_executor.preflight(action_type: intent.action_type, payload: intent.payload)
      return render_execution(intent:, execution: preflight_result) if preflight_result

      return render_confirmation(intent:) if intent.confirmation_required?

      execute_intent(intent:)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    private

    attr_reader :workspace, :chat_thread, :actor, :user_message, :content, :tool_metadata, :context_snapshot

    def build_context_snapshot
      ContextSnapshotBuilder.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: content
      ).call
    end

    def active_pending_action
      @active_pending_action ||= action_request_lifecycle.active_pending_confirmation
    end

    def pending_action_command
      return :confirm if content.match?(CONFIRM_MESSAGE_REGEX)
      return :cancel if content.match?(CANCEL_MESSAGE_REGEX)

      nil
    end

    def runtime_service
      @runtime_service ||= RuntimeService.new(
        message: content,
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          attachments: user_message.images.attachments,
          conversation_messages: context_snapshot.conversation_messages,
          context_snapshot:
        }
      )
    end

    def intent_reconciler
      @intent_reconciler ||= IntentReconciler.new(
        workspace:,
        actor:,
        chat_thread:,
        source_message: user_message,
        message_text: content,
        tool_metadata:,
        context_snapshot:
      )
    end

    def action_executor
      @action_executor ||= ActionExecutor.new(workspace:, actor:)
    end

    def action_request_lifecycle
      @action_request_lifecycle ||= ActionRequestLifecycle.new(chat_thread:, actor:)
    end

    def execution_truth_reconciler
      @execution_truth_reconciler ||= ExecutionTruthReconciler.new(workspace:)
    end

    def response_composer
      @response_composer ||= ResponseComposer.new(
        workspace:,
        actor:,
        prior_assistant_messages: prior_assistant_messages
      )
    end

    def prior_assistant_messages
      @prior_assistant_messages ||= chat_thread.chat_messages
        .where(role: ChatMessage::Roles::ASSISTANT)
        .order(id: :desc)
        .limit(3)
    end

    def render_non_action(assistant_content)
      assistant_content = normalized_assistant_content(assistant_content)
      assistant_message = create_assistant_message(
        content: assistant_content,
        status: ChatMessage::Statuses::COMPLETED
      )

      TurnOutcome.new(
        status: 'ok',
        user_message:,
        assistant_message:,
        assistant_content:,
        action_type: nil,
        data: {}
      )
    end

    def schema_summary_follow_up_response
      Chat::SchemaSummaryFollowUpResponder.new(
        message: content,
        conversation_messages: context_snapshot.conversation_messages
      ).call
    end

    def execute_direct_tool(action_type:, payload:)
      intent = direct_intent(action_type:, payload:)
      preflight_result = action_executor.preflight(action_type:, payload: intent.payload)
      return render_execution(intent:, execution: preflight_result) if preflight_result

      execute_intent(intent:)
    end

    def direct_sql_request?
      content.match?(/\A\s*(select|with)\b/i)
    end

    # rubocop:disable Metrics/AbcSize
    def render_confirmation(intent:)
      action_request = action_request_lifecycle.persist_pending_confirmation!(
        source_message: user_message,
        action_type: intent.action_type,
        payload: intent.payload
      )
      assistant_content = normalized_assistant_content(
        response_composer.confirmation_message(
          action_type: intent.action_type,
          proposed_message: intent.assistant_message,
          payload: intent.payload
        )
      )
      assistant_message = create_assistant_message(
        content: assistant_content,
        status: ChatMessage::Statuses::COMPLETED,
        metadata: {
          action_request_id: action_request.id,
          action_state: 'requires_confirmation',
          action_type: intent.action_type
        }
      )

      TurnOutcome.new(
        status: 'requires_confirmation',
        user_message:,
        assistant_message:,
        assistant_content:,
        action_type: intent.action_type,
        action_request:,
        data: {}
      )
    end
    # rubocop:enable Metrics/AbcSize

    def execute_intent(intent:)
      action_request_lifecycle.supersede_pending_confirmations!

      execution = execute_and_reconcile_intent(intent:)
      if query_save_name_conflict_execution?(intent:, execution:)
        return render_query_save_name_conflict(intent:, execution:)
      end

      render_executed_intent(intent:, execution:)
    end

    def execute_and_reconcile_intent(intent:)
      execution = action_executor.execute(action_type: intent.action_type, payload: intent.payload)
      execution_truth_reconciler.call(action_type: intent.action_type, payload: intent.payload, execution:)
    end

    def render_query_save_name_conflict(intent:, execution:)
      persist_query_save_name_conflict_for(intent:, execution:)
      render_non_action(query_save_name_conflict_message(execution:))
    end

    def render_executed_intent(intent:, execution:)
      query_card = query_card_payload(intent:, execution:)
      assistant_content = normalized_assistant_content(executed_assistant_content(intent:, execution:, query_card:))
      action_request = persist_executed_action_request(intent:, execution:, assistant_content:)
      outcome = render_execution(intent:, execution:, assistant_content:, action_request:, query_card:)
      persist_recent_query_state_for(intent:, execution:)
      persist_query_reference_for(intent:, execution:, assistant_message: outcome.assistant_message)
      clear_transient_state_for(intent:, execution:)
      outcome
    end

    # rubocop:disable Metrics/AbcSize
    def render_execution(intent:, execution:, assistant_content: nil, action_request: nil, query_card: nil)
      assistant_content = normalized_assistant_content(
        assistant_content || compose_execution_message(intent:, execution:)
      )
      assistant_message = create_assistant_message(
        content: assistant_content,
        status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
        metadata: {
          action_request_id: action_request&.id,
          action_state: execution.status,
          result_data: execution.data,
          action_type: intent.action_type,
          query_card:
        }.compact
      )

      TurnOutcome.new(
        status: execution.status,
        user_message:,
        assistant_message:,
        assistant_content:,
        action_type: intent.action_type,
        action_request:,
        execution:,
        data: execution.data,
        error_code: execution.error_code,
        redirect_path: execution.data[:redirect_path]
      )
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def confirm_pending_action
      if active_pending_action.expired?
        return render_non_action(I18n.t('app.workspaces.chat.errors.confirmation_expired'))
      end

      execution = action_executor.execute(
        action_type: active_pending_action.action_type,
        payload: active_pending_action.payload
      )
      execution = execution_truth_reconciler.call(
        action_type: active_pending_action.action_type,
        payload: active_pending_action.payload,
        execution:
      )
      intent = direct_intent(action_type: active_pending_action.action_type, payload: active_pending_action.payload)
      assistant_content = normalized_assistant_content(
        compose_execution_message(intent:, execution:)
      )
      action_request_lifecycle.mark_executed!(
        action_request: active_pending_action,
        result_status: execution.status,
        result_payload: {
          'user_message' => assistant_content,
          'data' => execution.data
        }
      )

      assistant_message = create_assistant_message(
        content: assistant_content,
        status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
        metadata: {
          action_request_id: active_pending_action.id,
          action_state: execution.status,
          confirmed_via_chat: true,
          result_data: execution.data,
          action_type: active_pending_action.action_type
        }
      )
      persist_recent_query_state_for(intent:, execution:)
      persist_query_reference_for(intent:, execution:, assistant_message:)

      TurnOutcome.new(
        status: execution.status,
        user_message:,
        assistant_message:,
        assistant_content:,
        action_type: active_pending_action.action_type,
        action_request: active_pending_action,
        execution:,
        data: execution.data,
        error_code: execution.error_code,
        redirect_path: execution.data[:redirect_path]
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def cancel_pending_action
      action_request_lifecycle.mark_canceled!(action_request: active_pending_action, canceled_by: actor)

      assistant_content = normalized_assistant_content(I18n.t('app.workspaces.chat.messages.action_canceled'))
      assistant_message = create_assistant_message(
        content: assistant_content,
        status: ChatMessage::Statuses::COMPLETED,
        metadata: {
          action_request_id: active_pending_action.id,
          action_state: 'canceled',
          canceled_via_chat: true,
          action_type: active_pending_action.action_type
        }
      )

      TurnOutcome.new(
        status: 'canceled',
        user_message:,
        assistant_message:,
        assistant_content:,
        action_type: active_pending_action.action_type,
        action_request: active_pending_action,
        data: {}
      )
    end

    def compose_execution_message(intent:, execution:)
      rich_read_actions = %w[member.list datasource.list query.list query.run]
      if execution.status == 'executed' && intent.read? && intent.action_type.in?(rich_read_actions)
        return execution.user_message
      end

      runtime_service.compose_tool_result_message(
        tool_name: intent.action_type,
        tool_arguments: intent.payload,
        execution:,
        fallback_message: response_composer.compose(execution:, action_type: intent.action_type)
      )
    end

    def create_assistant_message(content:, status:, metadata: {})
      chat_thread.chat_messages.create!(
        role: ChatMessage::Roles::ASSISTANT,
        status:,
        content: normalized_assistant_content(content),
        metadata:
      )
    end

    def query_card_payload(intent:, execution:)
      return {} unless execution.status == 'executed'
      return {} unless intent.action_type == 'query.run'

      Chat::QueryCardBuilder.new(
        workspace:,
        execution_data: execution.data,
        intent_payload: intent.payload
      ).call
    end

    def query_card_summary(intent:, execution:, query_card:)
      return compose_execution_message(intent:, execution:) if query_card.blank?

      Chat::QueryCardBuilder.new(
        workspace:,
        execution_data: execution.data,
        intent_payload: intent.payload
      ).summary_message
    end

    def executed_assistant_content(intent:, execution:, query_card:)
      return compose_execution_message(intent:, execution:) if query_card.blank?

      query_card_summary(intent:, execution:, query_card:)
    end

    def normalized_assistant_content(value)
      case value
      when Array
        value.flatten.filter_map do |entry|
          candidate = normalized_assistant_content(entry)
          candidate.presence
        end.first.to_s.strip
      else
        value.to_s.strip
      end
    end

    def capability_question?
      content.match?(CAPABILITY_QUESTION_REGEX)
    end

    def off_scope_general_question?
      return false if capability_question?
      return false unless question_like? || product_topic_question?
      return false if content.match?(IN_SCOPE_TOPIC_REGEX)
      return false if query_like_request?
      return false if recent_member_context_question?

      true
    end

    def question_like?
      content.match?(GENERAL_QUESTION_REGEX) || content.include?('?')
    end

    def product_topic_question?
      content.match?(PRODUCT_TOPIC_REGEX)
    end

    def recent_member_context_question?
      conversation_context_resolver.member_follow_up_question?(text: content)
    end

    def capability_summary_message
      categories = capability_category_items
      return restricted_capability_message if categories.empty?

      [
        I18n.t('app.workspaces.chat.messages.capability_summary_intro'),
        categories.map { |category| "- #{category}" }.join("\n"),
        I18n.t('app.workspaces.chat.messages.capability_summary_footer')
      ].join("\n\n")
    end

    def scope_limited_message
      categories = capability_category_items
      return restricted_scope_message if categories.empty?

      [
        I18n.t('app.workspaces.chat.messages.scope_limited_intro'),
        I18n.t('app.workspaces.chat.messages.scope_limited_supported_intro'),
        categories.map { |category| "- #{category}" }.join("\n"),
        I18n.t('app.workspaces.chat.messages.scope_limited_footer')
      ].join("\n\n")
    end

    def restricted_capability_message
      I18n.t(
        'app.workspaces.chat.messages.capability_summary_restricted',
        allowed_roles: I18n.t('app.workspaces.chat.executor.allowed_roles.user_admin_or_owner')
      )
    end

    def restricted_scope_message
      I18n.t(
        'app.workspaces.chat.messages.scope_limited_restricted',
        allowed_roles: I18n.t('app.workspaces.chat.executor.allowed_roles.user_admin_or_owner')
      )
    end

    def capability_category_items
      snapshot = context_snapshot.capability_snapshot.to_h.symbolize_keys
      {
        can_view_team_members: 'team',
        can_view_data_sources: 'data_sources',
        can_view_queries: 'queries',
        can_manage_workspace_settings: 'workspace'
      }.filter_map do |flag, category|
        I18n.t("app.workspaces.chat.messages.capability_categories.#{category}") if snapshot[flag]
      end
    end

    def conversation_context_resolver
      @conversation_context_resolver ||= Chat::ConversationContextResolver.new(
        workspace:,
        conversation_messages: context_snapshot.conversation_messages
      )
    end

    def data_source_setup_resolution
      if should_ignore_data_source_setup_for_current_message?
        data_source_setup_coordinator.clear!
        return nil
      end

      @data_source_setup_resolution ||= data_source_setup_coordinator.call
    end

    def handle_data_source_setup_resolution(resolution) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      persist_sanitized_user_content!(sanitized_user_content: resolution.sanitized_user_content)

      unless context_snapshot.capability_snapshot.to_h[:can_manage_data_sources]
        data_source_setup_coordinator.clear!
        return execute_direct_forbidden(action_type: 'datasource.create')
      end

      return render_non_action(resolution.assistant_message) if resolution.status == 'ask'

      intent = direct_intent(action_type: resolution.action_type, payload: resolution.payload)
      preflight_result = action_executor.preflight(action_type: intent.action_type, payload: intent.payload)
      return render_execution(intent:, execution: preflight_result) if preflight_result

      execution = action_executor.execute(action_type: intent.action_type, payload: intent.payload)

      if resolution.action_type == 'datasource.validate_connection' && execution.status == 'executed'
        follow_up = data_source_setup_coordinator.apply_validation_success(execution:)
        return render_non_action(follow_up.assistant_message)
      end

      if resolution.action_type == 'datasource.create' && execution.status == 'executed'
        data_source_setup_coordinator.clear!
      end

      render_execution(intent:, execution:)
    end

    def persist_sanitized_user_content!(sanitized_user_content:)
      return if sanitized_user_content.blank?
      return if user_message.content.to_s == sanitized_user_content

      user_message.update!(content: sanitized_user_content)
    end

    def should_resume_query_clarification?
      return false if context_snapshot.active_query_clarification.blank?
      return true if query_like_request?
      return true if content.match?(QUERY_CLARIFICATION_HINT_REGEX)
      return true if query_candidate_name_match?
      return true if query_clarification_follow_up?

      false
    end

    def should_resume_recent_query_scope_clarification?
      recent_query_scope_question.present? && resumed_query_scope_question.present?
    end

    def should_resume_recent_team_scope_clarification?
      recent_query_scope_question.present? && content.match?(QUERY_SCOPE_TEAM_FOLLOW_UP_REGEX)
    end

    def recent_query_scope_question
      return @recent_query_scope_question if defined?(@recent_query_scope_question)

      assistant_index = recent_query_scope_clarification_index
      @recent_query_scope_question =
        assistant_index.nil? ? nil : prior_query_user_message(before_index: assistant_index)
    end

    def resumed_query_scope_question
      return @resumed_query_scope_question if defined?(@resumed_query_scope_question)

      base_question = recent_query_scope_question.to_s.strip
      @resumed_query_scope_question = if base_question.blank? || !database_scope_selected?
                                        nil
                                      else
                                        merge_database_scope_into(question: base_question)
                                      end
    end

    def recent_query_scope_clarification_index
      context_snapshot.conversation_messages.rindex do |entry|
        assistant_entry?(entry) && conversation_entry_content(entry).match?(QUERY_SCOPE_ASSISTANT_REGEX)
      end
    end

    def prior_query_user_message(before_index:)
      context_snapshot.conversation_messages[0...before_index].reverse_each do |entry|
        next unless user_entry?(entry)

        text = conversation_entry_content(entry)
        return text if query_like_text?(text)
      end

      nil
    end

    def query_like_text?(text)
      return false unless text.to_s.match?(QUERY_LIKE_REGEX)
      return false if text.to_s.match?(/\b(team|teammates?|member|members|invite|invitation|workspace|role|roles)\b/i)

      text.to_s.match?(query_data_hint_regex) || context_snapshot.data_source_inventory.present?
    end

    def query_clarification_follow_up?
      content.match?(QUERY_CLARIFICATION_FOLLOW_UP_REGEX)
    end

    def query_scope_follow_up?
      database_scope_selected? || content.match?(QUERY_CLARIFICATION_HINT_REGEX)
    end

    def initial_query_scope_clarification_needed?
      return false if can_write_queries?
      return false unless content.match?(QUERY_SCOPE_AMBIGUOUS_USERS_REGEX)
      return false unless content.match?(QUERY_LIKE_REGEX)
      return false if content.match?(QUERY_SCOPE_TEAM_HINT_REGEX)
      return false if content.match?(QUERY_SCOPE_DATABASE_HINT_REGEX)
      return false if context_snapshot.data_source_inventory.blank?

      true
    end

    def query_scope_clarification_message
      return I18n.t('app.workspaces.chat.query.ask_scope') if can_write_queries?

      I18n.t(
        'app.workspaces.chat.query.ask_scope_read_only',
        member_allowed_roles: I18n.t('app.workspaces.chat.executor.allowed_roles.admin_or_owner'),
        query_allowed_roles: I18n.t('app.workspaces.chat.executor.allowed_roles.user_admin_or_owner')
      )
    end

    def can_write_queries?
      context_snapshot.capability_snapshot.to_h[:can_write_queries]
    end

    def database_scope_selected?
      explicit_database_scope_follow_up? || implicit_database_entity_follow_up?
    end

    def explicit_database_scope_follow_up?
      content.match?(QUERY_CLARIFICATION_FOLLOW_UP_REGEX)
    end

    def implicit_database_entity_follow_up?
      return false unless content.match?(QUERY_DATABASE_ENTITY_FOLLOW_UP_REGEX)
      return false if content.match?(/\b(team|workspace\s+members?|member|members)\b/i)

      context_snapshot.data_source_inventory.present?
    end

    def merge_database_scope_into(question:)
      normalized_question = question.to_s.strip.sub(/[!?]+\z/, '')
      return normalized_question if normalized_question.blank?
      return normalized_question if query_scope_already_present?(normalized_question)

      "#{normalized_question} in my connected database"
    end

    def query_scope_already_present?(question)
      question.match?(/\b(connected\s+database|connected\s+data\s+source|database|data\s+source)\b/i)
    end

    def user_entry?(entry)
      conversation_entry_role(entry) == 'user'
    end

    def assistant_entry?(entry)
      conversation_entry_role(entry) == 'assistant'
    end

    def conversation_entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def conversation_entry_content(entry)
      entry[:content].presence || entry['content'].presence || ''
    end

    def query_candidate_name_match? # rubocop:disable Metrics/AbcSize
      state = context_snapshot.active_query_clarification.to_h
      candidate_data_sources = Array(state['candidate_data_sources']).map { |candidate| candidate['name'].to_s }
      candidate_tables = Array(state['candidate_tables']).map do |candidate|
        candidate['qualified_name'].to_s.presence || candidate['name'].to_s
      end

      (candidate_data_sources + candidate_tables).compact.any? do |candidate|
        content.match?(/\b#{Regexp.escape(candidate)}\b/i)
      end
    end

    def query_like_request?
      return true if recent_query_follow_up_request?
      return false unless content.match?(QUERY_LIKE_REGEX)
      return false if content.match?(/\b(team|teammates?|member|members|invite|invitation|workspace|role|roles)\b/i)

      content.match?(query_data_hint_regex) || context_snapshot.data_source_inventory.present?
    end

    def recent_query_follow_up_request?
      QueryFollowUpMatcher.contextual_follow_up?(
        text: content,
        recent_query_reference: context_snapshot.recent_query_reference
      )
    end

    def recent_query_follow_up_payload
      {
        'question' => content,
        'base_sql' => recent_query_follow_up_base_sql,
        'base_question' => recent_query_follow_up_base_question,
        'base_query_name' => recent_query_follow_up_name,
        'data_source_id' => recent_query_follow_up_data_source_id,
        'data_source_name' => recent_query_follow_up_data_source_name
      }.compact
    end

    def recent_query_follow_up_reference
      @recent_query_follow_up_reference ||= context_snapshot.recent_query_reference.to_h.deep_stringify_keys
    end

    def recent_query_follow_up_state
      @recent_query_follow_up_state ||= context_snapshot.recent_query_state.to_h.deep_stringify_keys
    end

    def recent_query_follow_up_base_sql
      recent_query_follow_up_reference['sql'].presence || recent_query_follow_up_state['sql']
    end

    def recent_query_follow_up_base_question
      recent_query_follow_up_reference['original_question'].presence || recent_query_follow_up_state['question']
    end

    def recent_query_follow_up_name
      recent_query_follow_up_reference['saved_query_name'].presence ||
        recent_query_follow_up_reference['current_name'].presence ||
        recent_query_follow_up_state['saved_query_name']
    end

    def recent_query_follow_up_data_source_id
      recent_query_follow_up_reference['data_source_id'].presence || recent_query_follow_up_state['data_source_id']
    end

    def recent_query_follow_up_data_source_name
      recent_query_follow_up_reference['data_source_name'].presence || recent_query_follow_up_state['data_source_name']
    end

    def direct_intent(action_type:, payload:)
      ActionIntent.new(
        assistant_message: '',
        action_type:,
        payload: intent_reconciler.send(:canonical_payload, action_type:, raw_payload: payload),
        missing_information: [],
        finalize_without_tools: false,
        tool_definition: tool_definition_for(action_type:),
        source: 'deterministic',
        confidence: 1.0
      )
    end

    def execute_direct_forbidden(action_type:)
      intent = direct_intent(action_type:, payload: {})
      execution = action_executor.preflight(action_type:, payload: intent.payload)
      render_execution(intent:, execution:)
    end

    def tool_definition_for(action_type:)
      tool_metadata.find { |tool| tool[:name] == action_type }
    end

    def data_source_setup_coordinator
      @data_source_setup_coordinator ||= DataSourceSetupCoordinator.new(
        workspace:,
        actor:,
        chat_thread:,
        message_text: content
      )
    end

    def should_ignore_data_source_setup_for_current_message?
      return false if context_snapshot.active_data_source_setup.blank?
      return true if direct_sql_request?
      return true if query_like_request?
      return true if should_resume_query_clarification?
      return true if should_resume_recent_query_scope_clarification?

      connected_data_source_query_follow_up?
    end

    def connected_data_source_query_follow_up?
      context_snapshot.data_source_inventory.present? &&
        connected_data_source_reference? &&
        !data_source_setup_intent?
    end

    def connected_data_source_reference?
      content.match?(CONNECTED_DATA_SOURCE_REFERENCE_REGEX)
    end

    def data_source_setup_intent?
      content.match?(/\b(add|create|connect|configure|set\s*up|setup)\b/i)
    end

    def clear_transient_state_for(intent:, execution:)
      clear_query_save_name_conflict_state_for(intent:, execution:)

      return unless execution.status == 'executed'
      return unless intent.action_type == 'query.run'
      return if execution.data.to_h['clarification_required'] || execution.data.to_h[:clarification_required]

      query_clarification_state_store.clear!
    end

    def persist_recent_query_state_for(intent:, execution:)
      return unless execution.status == 'executed'

      handler = recent_query_state_handler_for(action_type: intent.action_type)
      return unless handler

      send(handler, intent:, execution:)
    end

    def persist_query_reference_for(intent:, execution:, assistant_message:)
      return unless execution.status == 'executed'

      handler = query_reference_handler_for(action_type: intent.action_type)
      return unless handler

      send(handler, intent:, execution:, assistant_message:)
    end

    def recent_query_state_handler_for(action_type:)
      {
        'query.run' => :persist_recent_query_run_state,
        'query.save' => :persist_recent_saved_query_state_for,
        'query.rename' => :persist_recent_renamed_query_state_for,
        'query.update' => :persist_recent_updated_query_state_for,
        'query.delete' => :clear_deleted_query_reference_for
      }[action_type]
    end

    def query_reference_handler_for(action_type:)
      {
        'query.run' => :persist_query_run_reference_for,
        'query.save' => :persist_saved_query_reference_for,
        'query.rename' => :persist_renamed_query_reference_for,
        'query.update' => :persist_updated_query_reference_for,
        'query.delete' => :persist_deleted_query_reference_for
      }[action_type]
    end

    def persist_recent_query_run_state(intent:, execution:)
      data = execution.data.to_h.deep_stringify_keys
      return if ActiveModel::Type::Boolean.new.cast(data['clarification_required'])

      recent_query_state_store.save(
        'question' => data['question'] || intent.payload['question'],
        'sql' => data['sql'],
        'data_source_id' => data.dig('data_source', 'id'),
        'data_source_name' => data.dig('data_source', 'name'),
        'row_count' => data['row_count'],
        'columns' => data['columns'],
        'saved_query_id' => nil,
        'saved_query_name' => nil
      )
    end

    def persist_recent_saved_query_state_for(execution:, intent:)
      _intent = intent
      persist_recent_saved_query_state(execution:)
    end

    def persist_recent_saved_query_state(execution:)
      data = execution.data.to_h.deep_stringify_keys
      query_payload = saved_query_payload(data:)
      merged_state = recent_saved_query_state_for(data:)

      if duplicate_saved_query_outside_current_thread?(data:, query_payload:)
        recent_query_state_store.save(clear_saved_query_linkage(state: merged_state))
        return
      end

      recent_query_state_store.save(attach_saved_query_linkage(state: merged_state, query_payload:))
    end

    def persist_recent_renamed_query_state_for(execution:, intent:)
      _intent = intent
      persist_recent_renamed_query_state(execution:)
    end

    def persist_recent_updated_query_state_for(execution:, intent:)
      _intent = intent
      persist_recent_saved_query_state(execution:)
    end

    def persist_recent_renamed_query_state(execution:) # rubocop:disable Metrics/AbcSize
      data = execution.data.to_h.deep_stringify_keys
      query_payload = data['query'].to_h.deep_stringify_keys
      return if query_payload.blank?

      existing_state = context_snapshot.recent_query_state.to_h.deep_stringify_keys
      recent_query_state_store.save(
        existing_state.merge(
          query_state_attributes_from_saved_query(data:),
          'saved_query_id' => query_payload['id'],
          'saved_query_name' => query_payload['name']
        )
      )
    end

    def clear_deleted_query_reference_for(execution:, intent:)
      _intent = intent
      clear_deleted_query_reference(execution:)
    end

    def clear_deleted_query_reference(execution:) # rubocop:disable Metrics/AbcSize
      data = execution.data.to_h.deep_stringify_keys
      deleted_query = data['deleted_query'].to_h.deep_stringify_keys
      return if deleted_query.blank?

      existing_state = context_snapshot.recent_query_state.to_h.deep_stringify_keys
      return unless existing_state['saved_query_id'].to_i == deleted_query['id'].to_i

      recent_query_state_store.save(
        existing_state.except('saved_query_id', 'saved_query_name')
      )
    end

    def persist_query_run_reference_for(intent:, execution:, assistant_message:)
      query_reference_store.record_query_run!(
        source_message: user_message,
        result_message: assistant_message,
        execution:,
        fallback_question: intent.payload['question']
      )
    end

    def current_thread_tracks_saved_query?(query_payload:)
      return false if query_payload['id'].to_s.strip.blank?

      recent_saved_query_id == query_payload['id'].to_i
    end

    def duplicate_saved_query_outside_current_thread?(data:, query_payload:)
      data['save_outcome'] == 'already_saved' && !current_thread_tracks_saved_query?(query_payload:)
    end

    def recent_saved_query_state_for(data:)
      context_snapshot.recent_query_state.to_h.deep_stringify_keys.merge(query_state_attributes_from_saved_query(data:))
    end

    def clear_saved_query_linkage(state:)
      state.except('saved_query_id', 'saved_query_name')
    end

    def attach_saved_query_linkage(state:, query_payload:)
      state.merge(
        'saved_query_id' => query_payload['id'],
        'saved_query_name' => query_payload['name']
      )
    end

    def recent_saved_query_id
      context_snapshot.recent_saved_query_reference.to_h.deep_stringify_keys['saved_query_id'].to_i
    end

    def persist_saved_query_reference_for(intent:, execution:, assistant_message:)
      query_reference_store.record_query_save!(
        source_message: user_message,
        result_message: assistant_message,
        execution:,
        fallback_question: intent.payload['question']
      )
    end

    def persist_renamed_query_reference_for(intent:, execution:, assistant_message:)
      _intent = intent
      query_reference_store.record_query_rename!(
        result_message: assistant_message,
        execution:
      )
    end

    def persist_updated_query_reference_for(intent:, execution:, assistant_message:)
      query_reference_store.record_query_update!(
        source_message: user_message,
        result_message: assistant_message,
        execution:,
        fallback_question: intent.payload['question']
      )
    end

    def persist_deleted_query_reference_for(intent:, execution:, assistant_message:)
      _intent = intent
      query_reference_store.record_query_delete!(
        result_message: assistant_message,
        execution:
      )
    end

    def query_state_attributes_from_saved_query(data:)
      query_payload = saved_query_payload(data:)
      existing_state = context_snapshot.recent_query_state.to_h.deep_stringify_keys

      {
        'question' => query_payload['question'] || existing_state['question'],
        'sql' => query_payload['sql'] || existing_state['sql'],
        'data_source_id' => query_payload.dig('data_source', 'id') || existing_state['data_source_id'],
        'data_source_name' => query_payload.dig('data_source', 'name') || existing_state['data_source_name']
      }
    end

    def saved_query_payload(data:)
      data['query'].to_h.deep_stringify_keys
    end

    def persist_executed_action_request(intent:, execution:, assistant_content:)
      return nil unless intent.write?

      action_request_lifecycle.persist_auto_executed_request!(
        source_message: user_message,
        action_type: intent.action_type,
        payload: intent.payload,
        execution_snapshot: {
          result_payload: {
            'user_message' => assistant_content,
            'data' => execution.data
          },
          status: execution.status
        }
      )
    end

    def query_data_hint_regex
      /\b(data\s+source|datasource|database|table|tables|schema|sql|query|queries|row|rows|column|columns)\b/i
    end

    def active_query_save_name_conflict
      @active_query_save_name_conflict ||= query_save_name_conflict_state_store.load
    end

    def query_save_name_conflict_resolution
      return nil if active_query_save_name_conflict.blank?
      return { type: :cancel } if pending_action_command == :cancel

      new_name = QueryNameParser.parse(text: content)
      return { type: :rename, name: new_name } if new_name.present?
      return { type: :keep_existing_name } if keep_generated_query_name?

      nil
    end

    def keep_generated_query_name?
      pending_action_command == :confirm || content.match?(QUERY_SAVE_KEEP_NAME_REGEX)
    end

    def handle_query_save_name_conflict_resolution(resolution)
      return cancel_query_save_name_conflict if resolution[:type] == :cancel

      resolved_name = resolution[:name] || active_query_save_name_conflict['proposed_name']
      execute_query_save_name_conflict_resolution(name: resolved_name)
    end

    def cancel_query_save_name_conflict
      query_save_name_conflict_state_store.clear!
      render_non_action(I18n.t('app.workspaces.chat.messages.action_canceled'))
    end

    def execute_query_save_name_conflict_resolution(name:)
      payload = active_query_save_name_conflict.slice('sql', 'question', 'data_source_id', 'data_source_name')
      payload['name'] = name
      query_save_name_conflict_state_store.clear!
      execute_direct_tool(action_type: 'query.save', payload:)
    end

    def query_save_name_conflict_execution?(intent:, execution:)
      intent.action_type == 'query.save' &&
        execution.status == 'validation_error' &&
        execution.error_code == 'generated_name_conflict'
    end

    def persist_query_save_name_conflict_for(intent:, execution:)
      data = execution.data.to_h.deep_stringify_keys
      conflicting_query = data['conflicting_query'].to_h.deep_stringify_keys

      query_save_name_conflict_state_store.save(
        intent.payload.slice('sql', 'question', 'data_source_id', 'data_source_name').merge(
          'proposed_name' => data['proposed_name'],
          'conflicting_query_id' => conflicting_query['id'],
          'conflicting_query_name' => conflicting_query['name']
        )
      )
    end

    def query_save_name_conflict_message(execution:)
      data = execution.data.to_h.deep_stringify_keys
      I18n.t(
        'app.workspaces.chat.query_library.generated_name_conflict',
        proposed_name: data['proposed_name'],
        existing_name: data.dig('conflicting_query', 'name')
      )
    end

    def clear_query_save_name_conflict_state_for(intent:, execution:)
      return unless execution.status == 'executed'
      return unless intent.action_type.start_with?('query.')

      query_save_name_conflict_state_store.clear!
    end

    def query_clarification_state_store
      @query_clarification_state_store ||= QueryClarificationStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
    end

    def recent_query_state_store
      @recent_query_state_store ||= RecentQueryStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
    end

    def query_reference_store
      @query_reference_store ||= QueryReferenceStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
    end

    def query_save_name_conflict_state_store
      @query_save_name_conflict_state_store ||= QuerySaveNameConflictStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
    end
  end
end
