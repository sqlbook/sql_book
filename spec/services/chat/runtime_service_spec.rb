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

  describe 'decision schema' do
    it 'serializes nested tool arguments as a string for Responses API strict json_schema' do
      arguments_schema = described_class::DECISION_SCHEMA
        .dig('properties', 'tool_calls', 'items', 'properties', 'arguments')

      expect(arguments_schema).to eq('type' => 'string')
    end
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

    it 'parses stringified tool arguments from model output' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Sure, I can do that.',
        tool_calls: [{ tool_name: 'member.invite', arguments: '{"email":"sam@example.com"}' }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'invite sam@example.com',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('member.invite')
      expect(decision.tool_calls.first.arguments).to eq('email' => 'sam@example.com')
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

    it 'uses non-structured model output as a conversational fallback' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      response = double('response', body: { output_text: 'Sure. What email should I invite?' }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(message: 'hello there', workspace:, actor:, tool_metadata:).call

      expect(decision.assistant_message).to eq('Sure. What email should I invite?')
      expect(decision.tool_calls).to eq([])
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'turns remove-by-name requests into member.remove when model returns no tool' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I can remove Chris Smith from this workspace. Please confirm if you want me to proceed.',
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
        message: 'Can we delete the user Chris Smith?',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls.size).to eq(1)
      expect(decision.tool_calls.first.tool_name).to eq('member.remove')
      expect(decision.tool_calls.first.arguments).to include(
        'email' => 'chris@example.com',
        'full_name' => 'Chris Smith'
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'overrides a query.list misclassification for explicit saved-query rename requests' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'how many users do I have',
        query: 'SELECT COUNT(*) AS row_count FROM public.users',
        author: actor,
        last_updated_by: actor
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Here are 1 saved queries.',
        tool_calls: [{ tool_name: 'query.list', arguments: {} }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: "Rename the query 'how many users do I have' to 'User Count'",
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          context_snapshot: instance_double(
            Chat::ContextSnapshot,
            recent_query_state: {
              'saved_query_id' => saved_query.id,
              'saved_query_name' => saved_query.name
            },
            query_references: [],
            conversation_messages: [],
            structured_context_lines: []
          ),
          conversation_messages: []
        }
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('query.rename')
      expect(decision.tool_calls.first.arguments).to include(
        'query_id' => saved_query.id,
        'query_name' => saved_query.name,
        'name' => 'User Count'
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'overrides a query.run misclassification for explicit saved-query rename requests' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: actor,
        last_updated_by: actor
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Here’s what I found from Staging App DB (1 row(s)):',
        tool_calls: [
          {
            tool_name: 'query.run',
            arguments: { question: 'Actually do you think you could rename it to DB User Count?' }
          }
        ],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: 'Actually do you think you could rename it to DB User Count?',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          context_snapshot: instance_double(
            Chat::ContextSnapshot,
            recent_query_state: {
              'saved_query_id' => saved_query.id,
              'saved_query_name' => saved_query.name
            },
            query_references: [],
            conversation_messages: [],
            structured_context_lines: []
          ),
          conversation_messages: []
        }
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('query.rename')
      expect(decision.tool_calls.first.arguments).to include(
        'query_id' => saved_query.id,
        'query_name' => saved_query.name,
        'name' => 'DB User Count'
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'overrides a query.list misclassification for quoted rename requests without the word to' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: actor,
        last_updated_by: actor
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Here are 2 saved queries.',
        tool_calls: [{ tool_name: 'query.list', arguments: {} }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: "Nice, could you rename it 'User Count [Test]' please?",
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          context_snapshot: instance_double(
            Chat::ContextSnapshot,
            recent_query_state: {
              'saved_query_id' => saved_query.id,
              'saved_query_name' => saved_query.name
            },
            recent_saved_query_reference: {
              'saved_query_id' => saved_query.id,
              'saved_query_name' => saved_query.name
            },
            query_references: [],
            conversation_messages: [],
            structured_context_lines: []
          ),
          conversation_messages: []
        }
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('query.rename')
      expect(decision.tool_calls.first.arguments).to include(
        'query_id' => saved_query.id,
        'query_name' => saved_query.name,
        'name' => 'User Count [Test]'
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'overrides a query.list misclassification for explicit saved-query delete requests' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User names and email addresses',
        query: 'SELECT first_name, last_name, email FROM public.users',
        author: actor,
        last_updated_by: actor
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Here are 1 saved queries.',
        tool_calls: [{ tool_name: 'query.list', arguments: {} }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: "Could you delete the query '#{saved_query.name}'?",
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          context_snapshot: instance_double(
            Chat::ContextSnapshot,
            recent_query_state: {
              'saved_query_id' => saved_query.id,
              'saved_query_name' => saved_query.name
            },
            query_references: [],
            conversation_messages: [],
            structured_context_lines: []
          ),
          conversation_messages: []
        }
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('query.delete')
      expect(decision.tool_calls.first.arguments).to include(
        'query_id' => saved_query.id,
        'query_name' => saved_query.name
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'acknowledges a recent wrong-query deletion instead of falling back to query.list' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'Here are 2 saved queries.',
        tool_calls: [{ tool_name: 'query.list', arguments: {} }],
        missing_information: [],
        finalize_without_tools: false
      }
      response = double('response', body: { output_text: llm_payload.to_json }.to_json)
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      decision = described_class.new(
        message: "Well, you've gone and deleted the wrong one!",
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            {
              role: 'assistant',
              content: 'I deleted the saved query "Users".',
              metadata: {
                result_data: {
                  deleted_query: {
                    id: 1,
                    name: 'Users'
                  }
                }
              }
            }
          ]
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to include('Users')
      expect(decision.assistant_message).to include('not the query you meant')
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
            { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name') }
          ]
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.missing_information).to eq(
        [I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role')]
      )
      expect(decision.assistant_message).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role')
      )
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'asks for role when invite follow-up context provides name and email but no role' do
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
            { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name') },
            { role: 'user', content: 'hello@sqlbook.com' }
          ]
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_role'))
      expect(decision.missing_information).to eq([I18n.t('app.workspaces.chat.planner.member_invite_needs_role')])
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'extracts inline invite roles from the initial request text' do
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
        message: [
          'Can you invite a new admin called Christopher Pattison?',
          'Their email address is chris.pattison@protonmail.com'
        ].join(' '),
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls.size).to eq(1)
      expect(decision.tool_calls.first.tool_name).to eq('member.invite')
      expect(decision.tool_calls.first.arguments).to include(
        'email' => 'chris.pattison@protonmail.com',
        'first_name' => 'Christopher',
        'last_name' => 'Pattison',
        'role' => Member::Roles::ADMIN
      )
    end

    it 'forces member.invite when invite follow-up context has name, email, and role across turns' do
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
        message: 'Admin',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            { role: 'user', content: 'Can I invite someone else?' },
            {
              role: 'assistant',
              content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
            },
            { role: 'user', content: 'Bob Jenkins hello@sqlbook.com' }
          ]
        }
      ).call

      expect(decision.tool_calls.size).to eq(1)
      expect(decision.tool_calls.first.tool_name).to eq('member.invite')
      expect(decision.tool_calls.first.arguments['email']).to eq('hello@sqlbook.com')
      expect(decision.tool_calls.first.arguments['first_name']).to eq('Bob')
      expect(decision.tool_calls.first.arguments['last_name']).to eq('Jenkins')
      expect(decision.tool_calls.first.arguments['role']).to eq(Member::Roles::ADMIN)
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'parses name and email from the same invite follow-up message' do
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
        message: 'Chris Smith, hello@sqlbook.com',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            { role: 'user', content: 'Can I invite someone else?' },
            { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_and_name') }
          ]
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_role'))
      expect(decision.finalize_without_tools).to be(true)
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
        [I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')]
      )
      expect(decision.assistant_message).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
      )
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'answers recent invited-member role questions from structured context when the model returns no tool' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I do not have enough current context to tell which person you mean.',
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
        message: 'Awesome, but what role did you add him as?',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
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
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to eq('I invited Chris Smith as User. Their invitation is currently Pending.')
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'asks for name and role together when only invite email is available' do
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
        message: 'Could you invite another for me please? hello@sqlbook.com',
        workspace:,
        actor:,
        tool_metadata:
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to eq(I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role'))
      expect(decision.finalize_without_tools).to be(true)
    end

    it 'accepts hedged role replies during invite follow-up' do
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
        message: 'I think admin',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
          conversation_messages: [
            { role: 'user', content: 'Could you invite another for me please? hello@sqlbook.com' },
            { role: 'assistant', content: I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role') },
            { role: 'user', content: 'Chris Smith' }
          ]
        }
      ).call

      expect(decision.tool_calls.first.tool_name).to eq('member.invite')
      expect(decision.tool_calls.first.arguments).to include(
        'email' => 'hello@sqlbook.com',
        'first_name' => 'Chris',
        'last_name' => 'Smith',
        'role' => Member::Roles::ADMIN
      )
      expect(decision.finalize_without_tools).to be(false)
    end

    it 'answers recent member follow-up questions from current workspace state when the model returns no tool' do
      invited_user = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')
      create(
        :member,
        workspace:,
        user: invited_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      llm_payload = {
        assistant_message: 'I do not have enough current context to tell which person you mean.',
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
        message: 'Which user are we talking about here?',
        workspace:,
        actor:,
        tool_metadata:,
        context: {
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
        }
      ).call

      expect(decision.tool_calls).to be_empty
      expect(decision.assistant_message).to eq(
        'We’re talking about Chris Smith (hello@sqlbook.com). They are currently Accepted as Admin in this workspace.'
      )
      expect(decision.finalize_without_tools).to be(true)
    end
  end

  describe '#compose_tool_result_message' do
    it 'preserves markdown line breaks from tool result rendering' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      response = double(
        'response',
        body: { output_text: "Here are your team members:\n\n- **Chris Smith**\n- **Bob Smith**" }.to_json
      )
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }

      http_client = double('http_client')
      allow(http_client).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      execution = Struct.new(:status, :data, :user_message).new('executed', { 'members' => [] }, 'fallback')
      rendered = described_class.new(
        message: 'Who are my team members?',
        workspace:,
        actor:,
        tool_metadata:
      ).compose_tool_result_message(
        tool_name: 'member.list',
        tool_arguments: {},
        execution:
      )

      expect(rendered).to include("\n\n- **Chris Smith**")
    end
  end
end
