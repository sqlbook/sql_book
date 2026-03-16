# frozen_string_literal: true

module Chat
  ContextSnapshot = Struct.new(
    :conversation_messages,
    :structured_context_lines,
    :active_pending_action,
    :referenced_member,
    :current_member,
    :recent_failure,
    :capability_snapshot,
    :invite_seed_details,
    keyword_init: true
  )
end
