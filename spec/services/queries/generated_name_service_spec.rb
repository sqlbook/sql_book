# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::GeneratedNameService, type: :service do
  let(:actor) { create(:user, preferred_locale: :en) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
    allow(ENV).to receive(:fetch).with('OPENAI_CHAT_MODEL', 'gpt-5-mini').and_return('gpt-5.3')
  end

  describe '.generate' do
    it 'returns the generated query name from output_text' do
      service = described_class.new(
        question: 'Who are the 5 longest standing users in my staging db?',
        sql: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 5',
        data_source:,
        actor:
      )
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return({ output_text: '5 longest standing users' }.to_json)
      http_client = instance_double(Net::HTTP, request: response)
      allow(service).to receive(:http_client).and_return(http_client)

      expect(service.call).to eq('5 longest standing users')
    end

    it 'returns text from nested output content when output_text is absent' do
      service = described_class.new(
        question: 'Which users are unconfirmed?',
        sql: 'SELECT id, email, confirmed_at FROM public.users WHERE confirmed_at IS NULL',
        data_source:,
        actor:
      )
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return(
        {
          output: [
            {
              content: [
                { type: 'output_text', text: 'Unconfirmed users' }
              ]
            }
          ]
        }.to_json
      )
      http_client = instance_double(Net::HTTP, request: response)
      allow(service).to receive(:http_client).and_return(http_client)

      expect(service.call).to eq('Unconfirmed users')
    end
  end

  describe '.generate_alternative' do
    it 'raises when the model returns a duplicate existing name' do
      service = described_class.new(
        question: 'How many users do I have?',
        sql: 'SELECT COUNT(*) AS user_count FROM public.users',
        data_source:,
        actor:,
        existing_names: ['User count'],
        avoid_existing_names: true
      )
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return({ output_text: 'User count' }.to_json)
      http_client = instance_double(Net::HTTP, request: response)
      allow(service).to receive(:http_client).and_return(http_client)

      expect { service.call }.to raise_error(
        Queries::GeneratedNameService::RequestError,
        'OpenAI returned a duplicate query name'
      )
    end
  end

  describe '#call' do
    it 'raises when OPENAI_API_KEY is missing' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)

      expect do
        described_class.generate(
          question: 'How many users do I have?',
          sql: 'SELECT COUNT(*) AS user_count FROM public.users',
          data_source:,
          actor:
        )
      end.to raise_error(Queries::GeneratedNameService::ConfigurationError, 'OPENAI_API_KEY is missing')
    end
  end
end
