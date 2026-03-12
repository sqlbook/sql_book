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

    it 'asks for required invite fields when invite intent is missing recipient details' do
      plan = described_class.new(message: 'invite my team', workspace:, actor:).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq('Sure. Please share their first name, last name, and email address.')
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
          { role: 'assistant', content: 'Sure. Please share their first name, last name, and email address.' }
        ]
      ).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Bob',
        'last_name' => 'Jenkins',
        'email' => 'hello@sqlbook.com'
      )
    end

    it 'parses first and last name when provided inline with email' do
      plan = described_class.new(
        message: 'Chris Smith, hello@sqlbook.com',
        workspace:,
        actor:,
        conversation_messages: [
          { role: 'user', content: 'Can I invite someone else?' },
          { role: 'assistant', content: 'Sure. Please share their first name, last name, and email address.' }
        ]
      ).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include(
        'first_name' => 'Chris',
        'last_name' => 'Smith',
        'email' => 'hello@sqlbook.com'
      )
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
  end
end
