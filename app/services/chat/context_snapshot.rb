# frozen_string_literal: true

module Chat
  ContextSnapshot = Struct.new(
    :conversation_messages,
    :structured_context_lines,
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
    keyword_init: true
  ) do
    def recent_query_reference
      Array(query_references).first.to_h.deep_stringify_keys
    end

    def recent_saved_query_reference
      Array(query_references)
        .find { |reference| reference.to_h.deep_stringify_keys['saved_query_id'].present? }
        .to_h
        .deep_stringify_keys
    end

    def recent_draft_query_reference
      Array(query_references)
        .find { |reference| reference.to_h.deep_stringify_keys['saved_query_id'].blank? }
        .to_h
        .deep_stringify_keys
    end
  end
end
