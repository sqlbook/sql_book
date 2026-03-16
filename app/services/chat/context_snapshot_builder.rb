# frozen_string_literal: true

module Chat
  class ContextSnapshotBuilder # rubocop:disable Metrics/ClassLength
    TRANSCRIPT_LIMIT = 12

    def initialize(chat_thread:, workspace:, actor:, current_message_text:)
      @chat_thread = chat_thread
      @workspace = workspace
      @actor = actor
      @current_message_text = current_message_text.to_s
    end

    def call # rubocop:disable Metrics/AbcSize
      ContextSnapshot.new(
        conversation_messages:,
        structured_context_lines: conversation_context_resolver.structured_context_lines + action_summary_lines,
        active_pending_action: active_pending_action_snapshot,
        referenced_member: conversation_context_resolver.recent_member_reference(text: current_message_text),
        current_member: conversation_context_resolver.current_member_for_recent_reference(text: current_message_text),
        recent_failure: recent_failure_snapshot,
        capability_snapshot: capability_resolver.summary,
        invite_seed_details: conversation_context_resolver.invite_seed_details(text: current_message_text)
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
  end
end
