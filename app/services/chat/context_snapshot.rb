# frozen_string_literal: true

module Chat
  ContextSnapshot = Struct.new(
    :conversation_messages,
    :structured_context_lines,
    :structured_context_sections,
    :active_pending_action,
    :active_data_source_setup,
    :active_query_clarification,
    :referenced_member,
    :current_member,
    :recent_failure,
    :capability_snapshot,
    :invite_seed_details,
    :data_source_inventory,
    :query_references,
    :recent_query_state,
    :active_focus,
    :pending_follow_up,
    :active_pending_follow_up,
    keyword_init: true
  ) do
    def recent_query_reference
      query_reference_payload(Array(query_references).first) || recent_query_state.to_h.deep_stringify_keys
    end

    def recent_saved_query_reference
      query_reference = Array(query_references)
        .find { |reference| query_reference_payload(reference).to_h['saved_query_id'].present? }

      query_reference_payload(query_reference) || saved_recent_query_state
    end

    def recent_draft_query_reference
      query_reference = Array(query_references)
        .find { |reference| query_reference_payload(reference).to_h['saved_query_id'].blank? }

      query_reference_payload(query_reference) || draft_recent_query_state
    end

    private

    def query_reference_payload(reference)
      payload = reference.to_h.deep_stringify_keys
      payload.presence
    end

    def saved_recent_query_state
      state = recent_query_state.to_h.deep_stringify_keys
      return {} if state['saved_query_id'].to_s.strip.blank?

      state
    end

    def draft_recent_query_state
      state = recent_query_state.to_h.deep_stringify_keys
      return {} if state['sql'].to_s.strip.blank?
      return {} if state['saved_query_id'].present?

      state
    end
  end
end
