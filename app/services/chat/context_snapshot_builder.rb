# frozen_string_literal: true

# rubocop:disable Layout/LineLength, Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/ParameterLists, Metrics/PerceivedComplexity
module Chat
  class ContextSnapshotBuilder
    TRANSCRIPT_LIMIT = 12

    def initialize(chat_thread:, workspace:, actor:, current_message_text:)
      @chat_thread = chat_thread
      @workspace = workspace
      @actor = actor
      @current_message_text = current_message_text.to_s
    end

    def call # rubocop:disable Metrics/AbcSize
      active_data_source_setup = data_source_setup_state_store.load
      active_query_clarification = pending_follow_up_payload_for(kind: 'query_scope_clarification')
      query_save_name_conflict = pending_follow_up_payload_for(kind: 'query_save_name_conflict')
      legacy_recent_query_state = recent_query_state_store.load
      query_references = query_reference_store.load
      recent_query_state = derived_recent_query_state(
        query_references:,
        legacy_recent_query_state:
      )
      recent_failure = recent_failure_snapshot
      active_pending_action = active_pending_action_snapshot
      active_pending_follow_up = active_pending_follow_up_snapshot
      member_references = recent_member_references
      pending_follow_up = pending_follow_up_snapshot(
        active_pending_follow_up:,
        query_save_name_conflict:,
        active_data_source_setup:,
        active_query_clarification:
      )
      active_focus = active_focus_snapshot(
        pending_follow_up:,
        active_data_source_setup:,
        active_query_clarification:,
        query_references:,
        recent_query_state:,
        member_references:
      )
      structured_context_sections = build_structured_context_sections(
        active_focus:,
        pending_follow_up:,
        query_references:,
        recent_query_state:,
        member_references:,
        active_pending_action:,
        recent_failure:
      )

      ContextSnapshot.new(
        conversation_messages:,
        structured_context_lines: flatten_structured_context_sections(structured_context_sections:),
        structured_context_sections:,
        active_pending_action: active_pending_action,
        active_data_source_setup: active_data_source_setup,
        active_query_clarification: active_query_clarification,
        referenced_member: conversation_context_resolver.recent_member_reference(text: current_message_text),
        current_member: conversation_context_resolver.current_member_for_recent_reference(text: current_message_text),
        recent_failure: recent_failure,
        capability_snapshot: capability_resolver.summary,
        invite_seed_details: conversation_context_resolver.invite_seed_details(text: current_message_text),
        data_source_inventory: data_source_inventory,
        query_references:,
        recent_query_state:,
        active_focus:,
        pending_follow_up:,
        active_pending_follow_up:
      )
    end

    private

    attr_reader :chat_thread, :workspace, :actor, :current_message_text

    def capability_resolver
      @capability_resolver ||= WorkspaceCapabilityResolver.new(workspace:, actor:)
    end

    def conversation_messages
      @conversation_messages ||= ChatMessage.where(chat_thread:)
        .where(role: [ChatMessage::Roles::USER, ChatMessage::Roles::ASSISTANT])
        .order(id: :desc)
        .limit(TRANSCRIPT_LIMIT)
        .reverse
        .map do |message|
          role_name = message.user? ? 'user' : 'assistant'
          {
            role: role_name,
            content: message.content.to_s,
            metadata: message.metadata.to_h
          }
        end
    end

    def conversation_context_resolver
      @conversation_context_resolver ||= ConversationContextResolver.new(
        workspace:,
        conversation_messages:
      )
    end

    def recent_action_requests
      @recent_action_requests ||= chat_thread.chat_action_requests
        .where(requested_by: actor)
        .where(superseded_at: nil)
        .order(id: :desc)
        .limit(6)
    end

    def active_pending_action_snapshot
      request = recent_action_requests.find(&:active_pending_confirmation?)
      return nil unless request

      {
        id: request.id,
        action_type: request.action_type,
        payload: request.payload.to_h,
        confirmation_expires_at: request.confirmation_expires_at
      }
    end

    def recent_failure_snapshot
      request = recent_action_requests.find do |candidate|
        [
          ChatActionRequest::Statuses::FORBIDDEN,
          ChatActionRequest::Statuses::VALIDATION_ERROR,
          ChatActionRequest::Statuses::EXECUTION_ERROR
        ].include?(candidate.status)
      end
      return nil unless request

      {
        action_type: request.action_type,
        status: request.status_name,
        message: request.result_payload.to_h['user_message'].to_s
      }
    end

    def data_source_setup_state_store
      @data_source_setup_state_store ||= DataSourceSetupStateStore.new(
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

    def data_source_inventory
      @data_source_inventory ||= workspace.data_sources.active.order(:name, :id).map do |data_source|
        {
          'id' => data_source.id,
          'name' => data_source.display_name,
          'source_type' => data_source.source_type,
          'selected_tables' => data_source.selected_tables,
          'tables_count' => data_source.tables_count
        }
      end
    end

    def build_structured_context_sections(
      active_focus:,
      pending_follow_up:,
      query_references:,
      recent_query_state:,
      member_references:,
      active_pending_action:,
      recent_failure:
    )
      sections = []

      if active_focus.present?
        sections << section(title: 'Active focus', lines: [focus_summary_line(focus: active_focus)])
      end

      if pending_follow_up.present?
        sections << section(
          title: 'Pending follow-up',
          lines: [pending_follow_up_summary_line(follow_up: pending_follow_up)]
        )
      end

      domain_reference_lines = []
      domain_reference_lines.concat(query_reference_summary_lines(query_references:))
      if domain_reference_lines.empty? && recent_query_state.present?
        domain_reference_lines << recent_query_summary_line(state: recent_query_state)
      end
      domain_reference_lines.concat(member_reference_summary_lines(member_references:))
      if domain_reference_lines.any?
        sections << section(title: 'Recent domain references', lines: domain_reference_lines)
      end

      if active_pending_action.present?
        sections << section(
          title: 'Pending confirmation',
          lines: [pending_action_summary_line(snapshot: active_pending_action)]
        )
      end

      if recent_failure.present?
        sections << section(title: 'Recent failure', lines: [failure_summary_line(snapshot: recent_failure)])
      end

      if data_source_inventory.any?
        sections << section(title: 'Connected data sources', lines: data_source_inventory_lines)
      end

      sections
    end

    def flatten_structured_context_sections(structured_context_sections:)
      Array(structured_context_sections).flat_map do |structured_section|
        title = structured_section[:title].presence || structured_section['title'].presence
        Array(structured_section[:lines].presence || structured_section['lines'].presence).compact_blank.map do |line|
          "#{title}: #{line}"
        end
      end
    end

    def section(title:, lines:)
      {
        title:,
        lines: Array(lines).compact_blank
      }
    end

    def data_source_inventory_lines
      data_source_inventory.map { |data_source| formatted_inventory_line(data_source:) }
    end

    def formatted_inventory_line(data_source:)
      selected_tables = Array(data_source['selected_tables']).first(8)
      selected_tables_text = selected_tables.any? ? " | selected tables: #{selected_tables.join(', ')}" : ''

      [
        "Connected data source: #{data_source['name']}",
        data_source['source_type'],
        "#{data_source['tables_count']} selected table(s)#{selected_tables_text}"
      ].join(' | ')
    end

    def recent_query_summary_line(state:)
      [
        'Recent query context',
        ("data_source=#{state['data_source_name']}" if state['data_source_name'].present?),
        ("row_count=#{state['row_count']}" if state['row_count'].present?),
        ("saved_query_name=#{state['saved_query_name']}" if state['saved_query_name'].present?),
        ("intent=#{query_intent_summary(reference: state)}" if query_intent_summary(reference: state).present?),
        ("result_shape=#{query_result_shape(reference: state)}" if query_result_shape(reference: state).present?),
        ("sql=#{state['sql'].to_s.tr("\n", ' ').truncate(120)}" if state['sql'].present?)
      ].compact.join(' | ')
    end

    def query_reference_summary_lines(query_references:)
      Array(query_references).first(3).map do |reference|
        payload = reference.to_h.deep_stringify_keys

        [
          'Query reference',
          ("name=#{payload['current_name']}" if payload['current_name'].present?),
          ("aliases=#{Array(payload['name_aliases']).join(', ')}" if Array(payload['name_aliases']).any?),
          ("saved_query=#{payload['saved_query_name']}" if payload['saved_query_name'].present?),
          ("data_source=#{payload['data_source_name']}" if payload['data_source_name'].present?),
          ("row_count=#{payload['row_count']}" if payload['row_count'].present?),
          ("intent=#{query_intent_summary(reference: payload)}" if query_intent_summary(reference: payload).present?),
          ("result_shape=#{query_result_shape(reference: payload)}" if query_result_shape(reference: payload).present?),
          (
            "refined_from_saved_query_id=#{payload['refined_saved_query_id']}" if payload['refined_saved_query_id'].present?
          ),
          ('is_active_refinement=true' if payload['refined_from_reference_id'].present?),
          ("sql=#{payload['sql'].to_s.tr("\n", ' ').truncate(120)}" if payload['sql'].present?)
        ].compact.join(' | ')
      end
    end

    def member_reference_summary_lines(member_references:)
      Array(member_references).first(2).map do |member|
        [
          'Member reference',
          ("member=#{member['full_name']}" if member['full_name'].present?),
          ("email=#{member['email']}" if member['email'].present?),
          ("summary=#{member_summary(member:)}" if member_summary(member:).present?)
        ].compact.join(' | ')
      end
    end

    def active_focus_snapshot(
      pending_follow_up:,
      active_data_source_setup:,
      active_query_clarification:,
      query_references:,
      recent_query_state:,
      member_references:
    )
      return focus_from_pending_follow_up(pending_follow_up:) if pending_follow_up.present?
      return data_source_setup_focus(state: active_data_source_setup) if active_data_source_setup.present?
      return query_clarification_focus(state: active_query_clarification) if active_query_clarification.present?

      query_focus = query_focus_snapshot(query_references:, recent_query_state:)
      return query_focus if query_focus.present?

      member_focus = member_focus_snapshot(member_references:)
      return member_focus if member_focus.present?

      workspace_focus_snapshot || datasource_action_focus_snapshot || {}
    end

    def pending_follow_up_snapshot(
      active_pending_follow_up:,
      query_save_name_conflict:,
      active_data_source_setup:,
      active_query_clarification:
    )
      return active_pending_follow_up if active_pending_follow_up.present?

      query_name_conflict_follow_up(state: query_save_name_conflict).presence ||
        query_clarification_follow_up(state: active_query_clarification).presence ||
        data_source_setup_follow_up(state: active_data_source_setup).presence ||
        {}
    end

    def active_pending_follow_up_snapshot
      snapshot = pending_follow_up_manager.active_payload
      return {} if snapshot.blank?

      payload = snapshot['payload'].to_h.deep_stringify_keys

      case snapshot['kind']
      when 'query_save_name_conflict'
        query_name_conflict_follow_up(state: payload)
      when 'query_scope_clarification'
        query_clarification_follow_up(state: payload)
      when 'datasource_setup'
        data_source_setup_follow_up(state: payload)
      when 'query_rename_suggestion'
        query_rename_suggestion_follow_up(snapshot:, payload:)
      when 'thread_rename_target'
        thread_rename_target_follow_up(snapshot:, payload:)
      else
        payload
      end
    end

    def pending_follow_up_payload_for(kind:)
      snapshot = pending_follow_up_manager.active_payload
      return {} if snapshot.blank?
      return {} unless snapshot['kind'] == kind

      snapshot['payload'].to_h.deep_stringify_keys
    end

    def focus_from_pending_follow_up(pending_follow_up:)
      snapshot = pending_follow_up.to_h.deep_stringify_keys
      snapshot.slice(
        'domain',
        'target_type',
        'target_id',
        'target_name',
        'data_source_id',
        'data_source_name'
      ).merge(
        'focus_kind' => 'flow',
        'last_result_kind' => snapshot['kind'],
        'result_summary' => snapshot['prompt_summary'],
        'follow_up_expected' => true
      ).compact_blank
    end

    def query_focus_snapshot(query_references:, recent_query_state:)
      reference = Array(query_references).first.to_h.deep_stringify_keys
      reference = recent_query_state.to_h.deep_stringify_keys if reference.blank?
      return {} if reference.blank?

      {
        'domain' => 'query',
        'focus_kind' => reference['saved_query_id'].present? ? 'object' : 'result',
        'target_type' => reference['saved_query_id'].present? ? 'saved_query' : 'draft_query',
        'target_id' => reference['saved_query_id'].presence || reference['id'],
        'target_name' => reference['saved_query_name'].presence || reference['current_name'],
        'data_source_id' => reference['data_source_id'],
        'data_source_name' => reference['data_source_name'],
        'last_action_type' => reference['saved_query_id'].present? ? 'query.save' : 'query.run',
        'last_result_kind' => 'query_result',
        'result_summary' => query_result_summary(reference:),
        'follow_up_expected' => false
      }.compact_blank
    end

    def member_focus_snapshot(member_references:)
      member = Array(member_references).first.to_h.deep_stringify_keys
      return {} if member.blank?

      {
        'domain' => 'member',
        'focus_kind' => 'object',
        'target_type' => 'member',
        'target_id' => member['member_id'],
        'target_name' => member['full_name'],
        'last_result_kind' => 'member_update',
        'result_summary' => member_summary(member:),
        'follow_up_expected' => false
      }.compact_blank
    end

    def workspace_focus_snapshot
      request = recent_action_requests.find do |candidate|
        candidate.status == ChatActionRequest::Statuses::EXECUTED &&
          candidate.action_type.start_with?('workspace.')
      end
      return {} unless request

      {
        'domain' => 'workspace',
        'focus_kind' => 'flow',
        'target_type' => 'workspace',
        'target_id' => workspace.id,
        'target_name' => workspace.name,
        'last_action_type' => request.action_type,
        'last_result_kind' => 'workspace_update',
        'result_summary' => workspace_change_summary_for(request:),
        'follow_up_expected' => false
      }.compact_blank
    end

    def datasource_action_focus_snapshot
      request = recent_action_requests.find do |candidate|
        candidate.status == ChatActionRequest::Statuses::EXECUTED &&
          candidate.action_type.start_with?('datasource.')
      end
      return {} unless request

      {
        'domain' => 'datasource',
        'focus_kind' => 'flow',
        'target_type' => 'data_source',
        'last_action_type' => request.action_type,
        'last_result_kind' => datasource_result_kind_for(request:),
        'result_summary' => datasource_change_summary_for(request:),
        'follow_up_expected' => false
      }.compact_blank
    end

    def data_source_setup_focus(state:)
      {
        'domain' => 'datasource',
        'focus_kind' => 'flow',
        'target_type' => 'data_source',
        'target_name' => state['name'],
        'last_result_kind' => 'datasource_validation',
        'result_summary' => setup_stage_summary(state:),
        'follow_up_expected' => true
      }.compact_blank
    end

    def query_clarification_focus(state:)
      {
        'domain' => 'query',
        'focus_kind' => 'clarification',
        'target_type' => 'table',
        'data_source_id' => state['data_source_id'],
        'last_result_kind' => 'clarification',
        'result_summary' => candidate_scope_summary(state:),
        'follow_up_expected' => true
      }.compact_blank
    end

    def query_name_conflict_follow_up(state:)
      payload = state.to_h.deep_stringify_keys
      return {} if payload.blank?

      {
        'domain' => 'query',
        'kind' => 'query_name_conflict',
        'prompt_summary' => %(Generated query name "#{payload['proposed_name']}" conflicts with saved query "#{payload['conflicting_query_name']}"),
        'expected_response_types' => %w[confirm choose_alternative provide_name cancel],
        'target_snapshot' => {
          'target_type' => 'draft_query',
          'data_source_id' => payload['data_source_id'],
          'data_source_name' => payload['data_source_name'],
          'target_name' => payload['proposed_name']
        }.compact_blank,
        'proposed_value' => payload['proposed_name']
      }.compact_blank
    end

    def query_rename_suggestion_follow_up(snapshot:, payload:)
      {
        'domain' => 'query',
        'kind' => 'query_rename_suggestion',
        'prompt_summary' => payload['prompt_summary'].presence ||
          %(Consider renaming "#{payload['current_name']}" to "#{payload['suggested_name']}"),
        'expected_response_types' => %w[confirm cancel],
        'target_snapshot' => {
          'target_type' => snapshot['target_type'].presence || 'saved_query',
          'target_id' => snapshot['target_id'],
          'target_name' => payload['current_name']
        }.compact_blank,
        'proposed_value' => payload['suggested_name'],
        'current_value' => payload['current_name']
      }.compact_blank
    end

    def thread_rename_target_follow_up(snapshot:, payload:)
      {
        'domain' => 'thread',
        'kind' => 'thread_rename_target',
        'prompt_summary' => payload['prompt_summary'].presence ||
          %(Rename the current chat to "#{payload['suggested_title']}"),
        'expected_response_types' => %w[confirm cancel],
        'target_snapshot' => {
          'target_type' => snapshot['target_type'].presence || 'chat_thread',
          'target_id' => snapshot['target_id'].presence || chat_thread.id,
          'target_name' => payload['suggested_title']
        }.compact_blank,
        'proposed_value' => payload['suggested_title']
      }.compact_blank
    end

    def query_clarification_follow_up(state:)
      return {} if state.blank?

      {
        'domain' => 'query',
        'kind' => 'query_clarification',
        'prompt_summary' => candidate_scope_summary(state:),
        'expected_response_types' => %w[provide_detail select_target cancel],
        'target_snapshot' => {
          'target_type' => 'table',
          'data_source_id' => state['data_source_id']
        }.compact_blank
      }.compact_blank
    end

    def data_source_setup_follow_up(state:)
      return {} if state.blank?

      {
        'domain' => 'datasource',
        'kind' => 'datasource_setup_step',
        'prompt_summary' => setup_stage_summary(state:),
        'expected_response_types' => %w[provide_detail select_target cancel],
        'target_snapshot' => {
          'target_type' => 'data_source',
          'target_name' => state['name']
        }.compact_blank
      }.compact_blank
    end

    def pending_action_summary_line(snapshot:)
      "action=#{snapshot[:action_type]} | awaiting confirmation"
    end

    def failure_summary_line(snapshot:)
      cleaned_message = snapshot[:message].to_s.tr("\n", ' ').truncate(140)
      "action=#{snapshot[:action_type]} | status=#{snapshot[:status]} | message=#{cleaned_message}"
    end

    def focus_summary_line(focus:)
      snapshot = focus.to_h.deep_stringify_keys
      [
        "domain=#{snapshot['domain']}",
        ("focus_kind=#{snapshot['focus_kind']}" if snapshot['focus_kind'].present?),
        ("target_type=#{snapshot['target_type']}" if snapshot['target_type'].present?),
        ("target_id=#{snapshot['target_id']}" if snapshot['target_id'].present?),
        ("target_name=#{snapshot['target_name']}" if snapshot['target_name'].present?),
        ("data_source=#{snapshot['data_source_name']}" if snapshot['data_source_name'].present?),
        ("last_action_type=#{snapshot['last_action_type']}" if snapshot['last_action_type'].present?),
        ("last_result_kind=#{snapshot['last_result_kind']}" if snapshot['last_result_kind'].present?),
        ("result_summary=#{snapshot['result_summary']}" if snapshot['result_summary'].present?),
        ("follow_up_expected=#{snapshot['follow_up_expected']}" unless snapshot['follow_up_expected'].nil?)
      ].compact.join(' | ')
    end

    def pending_follow_up_summary_line(follow_up:)
      snapshot = follow_up.to_h.deep_stringify_keys
      [
        "domain=#{snapshot['domain']}",
        ("kind=#{snapshot['kind']}" if snapshot['kind'].present?),
        ("prompt_summary=#{snapshot['prompt_summary']}" if snapshot['prompt_summary'].present?),
        ("expected=#{Array(snapshot['expected_response_types']).join(', ')}" if Array(snapshot['expected_response_types']).any?),
        ("target=#{follow_up_target_label(snapshot:)}" if follow_up_target_label(snapshot:).present?),
        ("proposed_value=#{snapshot['proposed_value']}" if snapshot['proposed_value'].present?)
      ].compact.join(' | ')
    end

    def follow_up_target_label(snapshot:)
      target_snapshot = snapshot['target_snapshot'].to_h
      return nil if target_snapshot.blank?

      target_snapshot['target_name'].presence || target_snapshot['target_type'].presence
    end

    def query_intent_summary(reference:)
      payload = reference.to_h.deep_stringify_keys
      payload['original_question'].to_s.presence ||
        payload['current_name'].to_s.presence ||
        payload['saved_query_name'].to_s.presence
    end

    def query_result_shape(reference:)
      payload = reference.to_h.deep_stringify_keys
      sql = payload['sql'].to_s.downcase
      columns = Array(payload['columns']).map(&:to_s).map(&:downcase)
      return 'grouped_count' if sql.include?('count(') && sql.include?('group by')
      return 'scalar_count' if sql.include?('count(')
      return 'user_list' if %w[first_name last_name email].all? { |column| columns.include?(column) }
      return 'table' if columns.any?

      'unknown'
    end

    def query_result_summary(reference:)
      payload = reference.to_h.deep_stringify_keys
      [
        payload['saved_query_name'].presence || payload['current_name'].presence,
        ("from #{payload['data_source_name']}" if payload['data_source_name'].present?),
        ("shape #{query_result_shape(reference: payload)}" if query_result_shape(reference: payload).present?),
        ("row_count #{payload['row_count']}" if payload['row_count'].present?)
      ].compact.join(' | ')
    end

    def member_summary(member:)
      role = member['role_name'].presence || member['role'].to_s.humanize.presence
      status = member['status_name'].presence || member['status'].to_s.humanize.presence
      [role, status].compact.join(' | ')
    end

    def setup_stage_summary(state:)
      [
        'Datasource setup is in progress',
        ("name=#{state['name']}" if state['name'].present?),
        "next_step=#{state['next_step'] || 'connection'}"
      ].compact.join(' | ')
    end

    def candidate_scope_summary(state:)
      [
        'Need query clarification',
        ("question=#{state['question']}" if state['question'].present?),
        ("candidate_data_sources=#{Array(state['candidate_data_sources']).pluck('name').join(', ')}" if Array(state['candidate_data_sources']).any?),
        ("candidate_tables=#{Array(state['candidate_tables']).pluck('qualified_name').join(', ')}" if Array(state['candidate_tables']).any?)
      ].compact.join(' | ')
    end

    def workspace_change_summary_for(request:)
      payload = request.result_payload.to_h.deep_stringify_keys
      payload['user_message'].to_s.strip.presence || request.action_type
    end

    def datasource_result_kind_for(request:)
      return 'datasource_list' if request.action_type == 'datasource.list'

      'datasource_validation'
    end

    def datasource_change_summary_for(request:)
      payload = request.result_payload.to_h.deep_stringify_keys
      payload['user_message'].to_s.strip.presence || request.action_type
    end

    def derived_recent_query_state(query_references:, legacy_recent_query_state:)
      recent_reference = Array(query_references).first.to_h.deep_stringify_keys
      return legacy_recent_query_state if recent_reference.blank?

      {
        'question' => recent_reference['original_question'],
        'sql' => recent_reference['sql'],
        'data_source_id' => recent_reference['data_source_id'],
        'data_source_name' => recent_reference['data_source_name'],
        'row_count' => recent_reference['row_count'],
        'columns' => recent_reference['columns'],
        'saved_query_id' => recent_reference['saved_query_id'],
        'saved_query_name' => recent_reference['saved_query_name']
      }.compact_blank
    end

    def recent_member_references
      [
        conversation_context_resolver.recent_updated_member,
        conversation_context_resolver.recent_invited_member,
        conversation_context_resolver.recent_removed_member
      ].compact.uniq do |member|
        member['member_id'].presence || member['email'].to_s.downcase.presence || member['full_name'].to_s.downcase
      end
    end

    def query_reference_store
      @query_reference_store ||= QueryReferenceStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
    end

    def pending_follow_up_manager
      @pending_follow_up_manager ||= PendingFollowUpManager.new(
        workspace:,
        chat_thread:,
        actor:
      )
    end
  end
end
# rubocop:enable Layout/LineLength, Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/ParameterLists, Metrics/PerceivedComplexity
