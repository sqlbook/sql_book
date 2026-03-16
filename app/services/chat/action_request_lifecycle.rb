# frozen_string_literal: true

require 'digest'

module Chat
  class ActionRequestLifecycle # rubocop:disable Metrics/ClassLength
    CONTEXT_KEYS = %w[workspace_id thread_id message_id].freeze

    def initialize(chat_thread:, actor:)
      @chat_thread = chat_thread
      @actor = actor
    end

    def active_pending_confirmation
      scoped_requests
        .pending_confirmation
        .where(superseded_at: nil)
        .order(id: :desc)
        .first
    end

    def persist_pending_confirmation!(source_message:, action_type:, payload:)
      fingerprint = action_fingerprint_for(action_type:, payload:)
      reusable_request = reusable_pending_confirmation(action_fingerprint: fingerprint)
      if reusable_request
        return refresh_pending_confirmation!(action_request: reusable_request, source_message:, payload:)
      end

      supersede_pending_confirmations!

      create_action_request!(
        source_message:,
        action_type:,
        payload:,
        action_fingerprint: fingerprint,
        idempotency_key: idempotency_key_for(action_fingerprint: fingerprint, source_message:),
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )
    end

    def persist_auto_executed_request!(source_message:, action_type:, payload:, execution_snapshot:)
      fingerprint = action_fingerprint_for(action_type:, payload:)
      idempotency_key = idempotency_key_for(action_fingerprint: fingerprint, source_message:)

      action_request = scoped_requests.find_or_initialize_by(idempotency_key:)
      action_request.assign_attributes(
        requested_by: actor,
        chat_message: source_message,
        source_message:,
        action_type:,
        payload:,
        action_fingerprint: fingerprint,
        result_payload: execution_snapshot[:result_payload],
        status: status_for_result(result_status: execution_snapshot[:status]),
        confirmation_token: nil,
        confirmation_expires_at: nil,
        executed_at: Time.current,
        superseded_at: nil
      )
      action_request.save!
      action_request
    end

    def mark_executed!(action_request:, result_status:, result_payload:)
      action_request.update!(
        status: status_for_result(result_status:),
        result_payload:,
        executed_at: Time.current,
        superseded_at: nil
      )
    end

    def mark_canceled!(action_request:, canceled_by:)
      action_request.update!(
        status: ChatActionRequest::Statuses::CANCELED,
        result_payload: { canceled_by: canceled_by.id },
        executed_at: Time.current,
        superseded_at: nil
      )
    end

    def supersede_pending_confirmations!(except_id: nil)
      relation = scoped_requests.pending_confirmation.where(superseded_at: nil)
      relation = relation.where.not(id: except_id) if except_id.present?
      relation.update_all(superseded_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def action_fingerprint_for(action_type:, payload:)
      stable_payload = payload.to_h.except(*CONTEXT_KEYS)
      fingerprint_parts = [
        chat_thread.workspace_id,
        chat_thread.id,
        actor.id,
        action_type,
        JSON.generate(deep_sorted_value(stable_payload))
      ]
      Digest::SHA256.hexdigest(fingerprint_parts.join(':'))
    end

    def idempotency_key_for(action_fingerprint:, source_message:)
      Digest::SHA256.hexdigest("#{action_fingerprint}:#{source_message.id}")
    end

    private

    attr_reader :chat_thread, :actor

    def scoped_requests
      chat_thread.chat_action_requests.where(requested_by: actor)
    end

    def reusable_pending_confirmation(action_fingerprint:)
      request = scoped_requests.pending_confirmation
        .where(superseded_at: nil, action_fingerprint:)
        .order(id: :desc)
        .first
      return nil unless request
      return nil if request.expired?

      request
    end

    def refresh_pending_confirmation!(action_request:, source_message:, payload:)
      action_request.update!(
        chat_message: source_message,
        source_message:,
        payload:,
        confirmation_token: SecureRandom.hex(20),
        confirmation_expires_at: ChatActionRequest::CONFIRMATION_WINDOW.from_now,
        result_payload: {},
        executed_at: nil,
        superseded_at: nil
      )
      action_request
    end

    # rubocop:disable Metrics/ParameterLists
    def create_action_request!(
      source_message:,
      action_type:,
      payload:,
      action_fingerprint:,
      idempotency_key:,
      status:
    )
      chat_thread.chat_action_requests.create!(
        requested_by: actor,
        chat_message: source_message,
        source_message:,
        action_type:,
        payload:,
        action_fingerprint:,
        idempotency_key:,
        status:
      )
    end
    # rubocop:enable Metrics/ParameterLists

    def deep_sorted_value(value)
      case value
      when Hash
        value.to_h.sort.to_h { |key, child| [key.to_s, deep_sorted_value(child)] }
      when Array
        value.map { |child| deep_sorted_value(child) }
      else
        value
      end
    end

    def status_for_result(result_status:)
      {
        'executed' => ChatActionRequest::Statuses::EXECUTED,
        'forbidden' => ChatActionRequest::Statuses::FORBIDDEN,
        'validation_error' => ChatActionRequest::Statuses::VALIDATION_ERROR,
        'execution_error' => ChatActionRequest::Statuses::EXECUTION_ERROR
      }.fetch(result_status, ChatActionRequest::Statuses::EXECUTION_ERROR)
    end
  end
end
