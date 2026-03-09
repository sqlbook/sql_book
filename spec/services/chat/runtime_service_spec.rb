# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::RuntimeService do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }
  let(:tool_metadata) { Tooling::WorkspaceTeamRegistry.tool_metadata }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_CHAT_MODEL', 'gpt-5-mini').and_return('gpt-5-mini')
  end

  describe '#call' do
    it 'falls back to planner when OPENAI_API_KEY is missing' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)

      decision = described_class.new(
        message: 'rename workspace to Runtime Name',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('workspace.update_name')
      expect(decision.tool_calls.first.arguments['name']).to eq('Runtime Name')
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'returns parsed llm decision when model output is valid' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Sure, I can do that.',
        tool_calls: [{ tool_name: 'member.list', arguments: {} }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'show my team members',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.assistant_message).to eq('Sure, I can do that.')
      expect(decision.tool_calls.size).to eq(1)
      expect(decision.tool_calls.first.tool_name).to eq('member.list')
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'parses nested response output with fenced json payload' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Please share the invite email.',
        tool_calls: [],
        missing_information: ['What email should I invite?'],
        finalize_without_tools: true
      }
      response_body = {
        output: [
          {
            content: [
              {
                text: "```json\n#{llm_payload.to_json}\n```"
              }
            ]
          }
        ]
      }.to_json
      response = double('response', body: response_body)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'what can you help me with?',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.assistant_message).to eq('Please share the invite email.')
      expect(decision.tool_calls).to be_empty
      expect(decision.missing_information).to eq(['What email should I invite?'])
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'asks for missing names when invite email follow-up is present but model returns no tool' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I can help with workspace and team actions.',
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'hello@sqlbook.com',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            { role: 'user', content: 'Can I invite someone else?' },
            { role: 'assistant', content: 'Sure. Please share their first name, last name, and email address.' }
          ]
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.missing_information).to eq([I18n.t('app.workspaces.chat.planner.member_invite_needs_name')])
      expect(decision.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_name'))
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'forces member.invite when invite follow-up context provides all required fields' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I can help with workspace and team actions.',
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'Bob Jenkins',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            { role: 'user', content: 'Can I invite someone else?' },
            { role: 'assistant', content: 'Sure. Please share their first name, last name, and email address.' },
            { role: 'user', content: 'hello@sqlbook.com' }
          ]
        }
      ).call

      expect(decision.tool_calls.size).to eq(1)
      expect(decision.tool_calls.first.tool_name).to eq('member.invite')
      expect(decision.tool_calls.first.arguments['email']).to eq('hello@sqlbook.com')
      expect(decision.tool_calls.first.arguments['first_name']).to eq('Bob')
      expect(decision.tool_calls.first.arguments['last_name']).to eq('Jenkins')
      expect(decision.tool_calls.first.arguments['role']).to eq(Member::Roles::USER)
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'asks for required invite fields when invite intent is present but model returns generic no-tool output' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I can help with workspace and team actions.',
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'Can I invite someone else?',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.missing_information).to eq(
        [I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name')]
      )
      expect(decision.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name'))
      expect(decision.finalize_without_tools).to be(true)
    end
  end
end
