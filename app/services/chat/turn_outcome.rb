# frozen_string_literal: true

module Chat
  TurnOutcome = Struct.new(
    :status,
    :user_message,
    :assistant_message,
    :assistant_content,
    :action_type,
    :action_request,
    :execution,
    :data,
    :error_code,
    :redirect_path,
    keyword_init: true
  ) do
    def messages
      [user_message, assistant_message].compact
    end
  end
end
