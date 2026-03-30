# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::PlannerService do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
  end

  describe 'plan schema' do
    it 'serializes payload as a string for Responses API strict json_schema' do
      payload_schema = described_class::PLAN_SCHEMA.dig('properties', 'payload')

      expect(payload_schema).to eq('type' => 'string')
    end
  end

  describe '#call' do
    it 'extracts workspace rename target without trailing question punctuation' do
      plan = described_class.new(message: 'Can you rename my workspace to Bumanarama?', workspace:, actor:).call

      expect(plan.action_type).to eq('workspace.update_name')
      expect(plan.payload).to include('name' => 'Bumanarama')
    end

    it 'asks for a workspace name when rename intent has no target name' do
      plan = described_class.new(message: 'rename workspace', workspace:, actor:).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq('Sure. What should the new workspace name be?')
    end

    it 'extracts chat-thread rename titles from explicit requests' do
      plan = described_class.new(
        message: 'Could you rename this chat to "10 longest standing users"?',
        workspace:,
        actor:
      ).call

      expect(plan.action_type).to eq('thread.rename')
      expect(plan.payload).to include('title' => '10 longest standing users')
    end

    it 'asks for required invite fields when invite intent is missing recipient details' do
      plan = described_class.new(message: 'invite my team', workspace:, actor:).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
      )
    end

    it 'keeps resend intent distinct from invite intent' do
      plan = described_class.new(message: 'resend invite to sam@example.com', workspace:, actor:).call

      expect(plan.action_type).to eq('member.resend_invite')
      expect(plan.payload).to include('email' => 'sam@example.com')
    end

    it 'creates an invite action when required invite fields are present' do
      plan = described_class.new(message: 'invite Sam Jenkins sam@example.com as admin', workspace:, actor:).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Sam',
        'last_name' => 'Jenkins',
        'email' => 'sam@example.com',
        'role' => Member::Roles::ADMIN
      )
    end

    it 'parses stringified payload from llm plan output' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      response_body = {
        output_text: {
          assistant_message: 'Sure, I can rename it.',
          action_type: 'workspace.update_name',
          payload: '{"name":"Renamed Workspace"}'
        }.to_json
      }.to_json
      response = double('response', body: response_body)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow_any_instance_of(described_class).to receive(:http_client).and_return(http_client)

      plan = described_class.new(message: 'rename workspace to Renamed Workspace', workspace:, actor:).call

      expect(plan.action_type).to eq('workspace.update_name')
      expect(plan.payload).to eq('name' => 'Renamed Workspace')
    end

    it 'treats invite follow-ups with an email as member.invite' do
      plan = described_class.new(
        message: 'Their name is Bob Jenkins and their email is hello@sqlbook.com',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Can I invite someone else?' },
          { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name') }
        ]
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_role'))
    end

    it 'executes invite follow-up once the role is provided' do
      plan = described_class.new(
        message: 'Admin',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Can I invite someone else?' },
          {
            role: 'assistant',
            content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
          },
          { role: 'user', content: 'Their name is Bob Jenkins and their email is hello@sqlbook.com' }
        ]
      ).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Bob',
        'last_name' => 'Jenkins',
        'email' => 'hello@sqlbook.com',
        'role' => Member::Roles::ADMIN
      )
    end

    it 'parses first and last name when provided inline with email' do
      plan = described_class.new(
        message: 'Chris Smith, hello@sqlbook.com',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Can I invite someone else?' },
          { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name') }
        ]
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_role'))
    end

    it 'treats member detail follow-ups as member listing when prior context is team members' do
      plan = described_class.new(
        message: 'what are their names and details?',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Show me my current team members please' },
          { role: 'assistant', content: 'Found 2 team members.' }
        ]
      ).call

      expect(plan.action_type).to eq('member.list')
    end

    it 'treats direct member detail requests as member listing' do
      plan = described_class.new(
        message: 'show team member names and emails',
        workspace:,
        actor:
      ).call

      expect(plan.action_type).to eq('member.list')
    end

    it 'resolves member removal by a unique workspace member name' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      plan = described_class.new(
        message: 'Can we delete the user Chris Smith?',
        workspace:,
        actor:
      ).call

      expect(plan.action_type).to eq('member.remove')
      expect(plan.payload).to include(
        'member_id' => workspace.members.find_by(user: teammate).id,
        'email' => 'chris@example.com',
        'full_name' => 'Chris Smith'
      )
    end

    it 'treats promote phrasing as a member role update intent' do
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      member = create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      plan = described_class.new(
        message: 'Promote Bob Smith to Admin',
        workspace:,
        actor:
      ).call

      expect(plan.action_type).to eq('member.update_role')
      expect(plan.payload).to include(
        'member_id' => member.id,
        'email' => 'bob@example.com',
        'full_name' => 'Bob Smith',
        'role' => Member::Roles::ADMIN
      )
    end

    it 'uses recent removed member context when asked to invite them back, but still asks for role' do
      plan = described_class.new(
        message: 'Thanks, could you invite him back actually?',
        workspace:,
        actor:,
        conversation_messages: [
          {
            role: 'assistant',
            content: 'Chris Smith has been removed from the workspace.',
            metadata: {
              result_data: {
                removed_member: {
                  full_name: 'Chris Smith',
                  first_name: 'Chris',
                  last_name: 'Smith',
                  email: 'hello@sqlbook.com',
                  role_name: 'User',
                  status_name: 'Accepted'
                }
              }
            }
          }
        ]
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_role'))
    end

    it 'executes invite-back flow once the role is supplied after the role prompt' do
      plan = described_class.new(
        message: 'User',
        workspace:,
        actor:,
        conversation_messages: [
          {
            role: 'assistant',
            content: 'Chris Smith has been removed from the workspace.',
            metadata: {
              result_data: {
                removed_member: {
                  full_name: 'Chris Smith',
                  first_name: 'Chris',
                  last_name: 'Smith',
                  email: 'hello@sqlbook.com',
                  role_name: 'User',
                  status_name: 'Accepted'
                }
              }
            }
          },
          { role: 'user', content: 'Thanks, could you invite him back actually?' },
          {
            role: 'assistant',
            content: I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
          }
        ]
      ).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Chris',
        'last_name' => 'Smith',
        'email' => 'hello@sqlbook.com',
        'role' => Member::Roles::USER
      )
    end

    it 'answers recent invited-member role questions from structured context' do
      plan = described_class.new(
        message: 'Awesome, but what role did you add him as?',
        workspace:,
        actor:,
        conversation_messages: [
          {
            role: 'assistant',
            content: 'Invitation sent to hello@sqlbook.com.',
            metadata: {
              result_data: {
                invited_member: {
                  full_name: 'Chris Smith',
                  first_name: 'Chris',
                  last_name: 'Smith',
                  email: 'hello@sqlbook.com',
                  role_name: 'User',
                  status_name: 'Pending'
                }
              }
            }
          }
        ]
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq('I invited Chris Smith as User. Their invitation is currently Pending.')
    end

    it 'asks for name and role together when email is provided without the other invite fields' do
      plan = described_class.new(
        message: 'Could you invite another for me please? hello@sqlbook.com',
        workspace:,
        actor:
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role'))
    end

    it 'treats hedged role replies as explicit invite roles' do
      plan = described_class.new(
        message: 'I think admin',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Could you invite another for me please? hello@sqlbook.com' },
          { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role') },
          { role: 'user', content: 'Chris Smith' }
        ]
      ).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Chris',
        'last_name' => 'Smith',
        'email' => 'hello@sqlbook.com',
        'role' => Member::Roles::ADMIN
      )
    end

    it 'answers recent member follow-up questions from current workspace state' do
      invited_user = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')
      create(
        :member,
        workspace:,
        user: invited_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      plan = described_class.new(
        message: 'Which user are we talking about here?',
        workspace:,
        actor:,
        conversation_messages: [
          {
            role: 'assistant',
            content: 'Invitation sent to hello@sqlbook.com.',
            metadata: {
              result_data: {
                invited_member: {
                  full_name: 'Chris Smith',
                  first_name: 'Chris',
                  last_name: 'Smith',
                  email: 'hello@sqlbook.com',
                  role_name: 'User',
                  status_name: 'Pending'
                }
              }
            }
          }
        ]
      ).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq(
        'We’re talking about Chris Smith (hello@sqlbook.com). They are currently Accepted as Admin in this workspace.'
      )
    end
  end
end
