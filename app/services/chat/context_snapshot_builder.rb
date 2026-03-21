# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
      active_query_clarification = query_clarification_state_store.load
      recent_query_state = recent_query_state_store.load

      ContextSnapshot.new(
        conversation_messages:,
        structured_context_lines: (
          conversation_context_resolver.structured_context_lines +
          data_source_context_lines(
            active_data_source_setup:,
            active_query_clarification:,
            recent_query_state:
          ) +
          action_summary_lines
        ),
        active_pending_action: active_pending_action_snapshot,
        active_data_source_setup: active_data_source_setup,
        active_query_clarification: active_query_clarification,
        referenced_member: conversation_context_resolver.recent_member_reference(text: current_message_text),
        current_member: conversation_context_resolver.current_member_for_recent_reference(text: current_message_text),
        recent_failure: recent_failure_snapshot,
        capability_snapshot: capability_resolver.summary,
        invite_seed_details: conversation_context_resolver.invite_seed_details(text: current_message_text),
        data_source_inventory: data_source_inventory,
        recent_query_state:
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

    def action_summary_lines
      recent_action_requests.filter_map do |request|
        action_summary_line_for(request:)
      end
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

    def action_summary_line_for(request:)
      return pending_action_summary_line(request:) if request.pending_confirmation?
      return failure_action_summary_line(request:) if failed_action_request?(request)

      nil
    end

    def pending_action_summary_line(request:)
      "Pending action: #{request.action_type} | awaiting confirmation"
    end

    def failure_action_summary_line(request:)
      payload = request.result_payload.to_h
      message = payload['user_message'].to_s.strip.presence || request.action_type
      "Recent failed action: #{request.action_type} | #{request.status_name} | #{message}"
    end

    def failed_action_request?(request)
      [
        ChatActionRequest::Statuses::FORBIDDEN,
        ChatActionRequest::Statuses::VALIDATION_ERROR,
        ChatActionRequest::Statuses::EXECUTION_ERROR
      ].include?(request.status)
    end

    def data_source_setup_state_store
      @data_source_setup_state_store ||= DataSourceSetupStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      )
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

    def data_source_context_lines(active_data_source_setup:, active_query_clarification:, recent_query_state:)
      lines = []

      lines.concat(data_source_inventory_lines)

      lines << data_source_setup_summary_line(state: active_data_source_setup) if active_data_source_setup.present?

      if active_query_clarification.present?
        lines << query_clarification_summary_line(state: active_query_clarification)
      end

      lines << recent_query_summary_line(state: recent_query_state) if recent_query_state.present?

      lines.compact
    end

    def data_source_inventory_lines
      data_source_inventory.map { |data_source| formatted_inventory_line(data_source:) }
    end

    def data_source_setup_summary_line(state:)
      available_table_count = Array(state['available_tables']).sum { |group| Array(group['tables']).size }
      [
        'Active data source setup',
        ("name=#{state['name']}" if state['name'].present?),
        ("source_type=#{state['source_type']}" if state['source_type'].present?),
        ("host=#{state['host']}" if state['host'].present?),
        ("database_name=#{state['database_name']}" if state['database_name'].present?),
        ("username=#{state['username']}" if state['username'].present?),
        ("available_tables=#{available_table_count}" if available_table_count.positive?),
        ("selected_tables=#{Array(state['selected_tables']).join(', ')}" if Array(state['selected_tables']).any?),
        "next_step=#{state['next_step'] || 'connection'}"
      ].compact.join(' | ')
    end

    def query_clarification_summary_line(state:)
      candidate_data_sources = Array(state['candidate_data_sources']).pluck('name')
      candidate_tables = Array(state['candidate_tables']).pluck('qualified_name')

      [
        'Active query clarification',
        ("question=#{state['question']}" if state['question'].present?),
        ("step=#{state['step']}" if state['step'].present?),
        ("data_source_id=#{state['data_source_id']}" if state['data_source_id'].present?),
        ("candidate_data_sources=#{candidate_data_sources.join(', ')}" if candidate_data_sources.any?),
        ("candidate_tables=#{candidate_tables.join(', ')}" if candidate_tables.any?)
      ].compact.join(' | ')
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
        ("sql=#{state['sql'].to_s.tr("\n", ' ').truncate(120)}" if state['sql'].present?)
      ].compact.join(' | ')
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
