# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::ResponseComposer do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }

  describe '#compose' do
    it 'mentions the allowed roles for forbidden actions' do
      composer = described_class.new(workspace:, actor:)
      execution = Chat::ActionExecutor::Result.new(
        status: 'forbidden',
        user_message: I18n.t('app.workspaces.chat.executor.forbidden'),
        data: {},
        error_code: 'forbidden_role'
      )

      message = composer.compose(execution:, action_type: 'member.remove')

      expect(message).to include('Admin')
      expect(message).to include('Workspace owner')
    end

    it 'avoids repeating the same forbidden template as the previous assistant reply' do
      previous_message = build(
        :chat_message,
        role: ChatMessage::Roles::ASSISTANT,
        content: [
          'You can\'t remove team members with your current workspace role.',
          'Please ask an Admin or Workspace owner.'
        ].join(' ')
      )
      composer = described_class.new(
        workspace:,
        actor:,
        prior_assistant_messages: [previous_message]
      )
      execution = Chat::ActionExecutor::Result.new(
        status: 'forbidden',
        user_message: I18n.t('app.workspaces.chat.executor.forbidden'),
        data: {},
        error_code: 'forbidden_role'
      )

      message = composer.compose(execution:, action_type: 'member.remove')

      expect(message).not_to eq(previous_message.content)
      expect(message).to include('Admin')
    end

    it 'includes the invited role in member invite success replies' do
      composer = described_class.new(workspace:, actor:)
      execution = Chat::ActionExecutor::Result.new(
        status: 'executed',
        user_message: 'Invitation sent to hello@example.com.',
        data: {
          invited_member: {
            email: 'hello@example.com',
            role_name: 'Admin'
          }
        },
        error_code: nil
      )

      message = composer.compose(execution:, action_type: 'member.invite')

      expect(message).to include('hello@example.com')
      expect(message).to include('Admin')
    end
  end
end
