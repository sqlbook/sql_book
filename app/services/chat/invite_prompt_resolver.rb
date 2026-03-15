# frozen_string_literal: true

module Chat
  class InvitePromptResolver
    PROMPT_KEY_MAP = {
      [true, true, true] => 'app.workspaces.chat.planner.member_invite_needs_email_name_and_role',
      [false, true, true] => 'app.workspaces.chat.planner.member_invite_needs_name_and_role',
      [true, false, true] => 'app.workspaces.chat.planner.member_invite_needs_email_and_role',
      [true, true, false] => 'app.workspaces.chat.planner.member_invite_needs_email_and_name',
      [false, false, true] => 'app.workspaces.chat.planner.member_invite_needs_role',
      [true, false, false] => 'app.workspaces.chat.planner.member_invite_needs_email',
      [false, true, false] => 'app.workspaces.chat.planner.member_invite_needs_name'
    }.freeze

    class << self
      def key_for(missing_fields:)
        PROMPT_KEY_MAP[flags_for(missing_fields:)]
      end

      private

      def flags_for(missing_fields:)
        fields = Array(missing_fields).map(&:to_s)

        [
          fields.include?('email'),
          fields.intersect?(%w[first_name last_name]),
          fields.include?('role')
        ]
      end
    end
  end
end
