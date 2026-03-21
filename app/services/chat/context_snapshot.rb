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
    :recent_query_state,
    keyword_init: true
  )
end
