# frozen_string_literal: true

module Chat
  class PendingFollowUpManager
    def initialize(workspace:, chat_thread:, actor:)
      @workspace = workspace
      @chat_thread = chat_thread
      @actor = actor
    end

    def active_record
      scope.active.recent_first.first
    end

    def active_payload
      active_record&.serialized_payload || {}
    end

    def replace!(kind:, domain:, payload:, source_message: nil, target_type: nil, target_id: nil) # rubocop:disable Metrics/ParameterLists
      ActiveRecord::Base.transaction do
        supersede_active!
        scope.create!(
          workspace:,
          kind:,
          domain:,
          payload: normalize_payload(payload),
          target_type: target_type.presence,
          target_id: integer_or_nil(target_id),
          source_message:
        )
      end
    end

    def resolve_active!
      transition_active!(status: ChatPendingFollowUp::Statuses::RESOLVED, resolved_at: Time.current)
    end

    def cancel_active!
      transition_active!(status: ChatPendingFollowUp::Statuses::CANCELED, resolved_at: Time.current)
    end

    def clear_active!
      supersede_active!
      {}
    end

    def clear_kind!(kind)
      update_records!(
        scope.active.where(kind: kind),
        status: ChatPendingFollowUp::Statuses::SUPERSEDED,
        superseded_at: Time.current
      )
      {}
    end

    private

    attr_reader :workspace, :chat_thread, :actor

    def scope
      chat_thread.chat_pending_follow_ups.where(created_by: actor)
    end

    def supersede_active!
      update_records!(
        scope.active,
        status: ChatPendingFollowUp::Statuses::SUPERSEDED,
        superseded_at: Time.current
      )
    end

    def transition_active!(status:, resolved_at:)
      record = active_record
      return {} unless record

      record.update!(status:, resolved_at:, superseded_at: nil)
      record.serialized_payload
    end

    def normalize_payload(payload)
      payload.to_h.deep_stringify_keys.compact_blank
    end

    def integer_or_nil(value)
      return nil if value.to_s.strip.blank?
      return value.to_i if value.to_s.match?(/\A\d+\z/)

      value
    end

    def update_records!(records, **attributes)
      records.find_each do |record|
        record.update!(attributes)
      end
    end
  end
end
