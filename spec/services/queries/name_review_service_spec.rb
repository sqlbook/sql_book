# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::NameReviewService, type: :service do
  let(:actor) { create(:user, preferred_locale: :en) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
    allow(ENV).to receive(:fetch).with('OPENAI_CHAT_MODEL', 'gpt-5-mini').and_return('gpt-5.3')
  end

  it 'returns a stale review with a suggested name when the title is clearly outdated' do
    service = described_class.new(
      current_name: '5 longest standing users',
      question: 'Show 10 longest standing users instead',
      sql: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 10',
      data_source:,
      actor:
    )
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(
      {
        output_text: {
          status: 'stale',
          suggested_name: '10 longest standing users',
          reason: 'The LIMIT changed from 5 to 10.'
        }.to_json
      }.to_json
    )
    http_client = instance_double(Net::HTTP, request: response)
    allow(service).to receive(:http_client).and_return(http_client)

    result = service.call

    expect(result.status).to eq('stale')
    expect(result.suggested_name).to eq('10 longest standing users')
  end

  it 'returns aligned when the current title still fits' do
    service = described_class.new(
      current_name: 'Longest standing users',
      question: 'Show 10 longest standing users instead',
      sql: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 10',
      data_source:,
      actor:
    )
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(
      {
        output_text: {
          status: 'aligned',
          suggested_name: nil,
          reason: 'The current title still describes the query.'
        }.to_json
      }.to_json
    )
    http_client = instance_double(Net::HTTP, request: response)
    allow(service).to receive(:http_client).and_return(http_client)

    result = service.call

    expect(result.status).to eq('aligned')
    expect(result.suggested_name).to be_nil
  end

  it 'returns uncertain from nested output content when a rename is not obvious' do
    service = described_class.new(
      current_name: 'Workspace count',
      question: 'Also include created_at',
      sql: 'SELECT name, created_at FROM public.workspaces',
      data_source:,
      actor:
    )
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return(
      {
        output: [
          {
            content: [
              {
                type: 'output_text',
                text: {
                  value: {
                    status: 'uncertain',
                    suggested_name: nil,
                    reason: 'The purpose may have shifted, but it is not clearly wrong.'
                  }.to_json
                }
              }
            ]
          }
        ]
      }.to_json
    )
    http_client = instance_double(Net::HTTP, request: response)
    allow(service).to receive(:http_client).and_return(http_client)

    result = service.call

    expect(result.status).to eq('uncertain')
    expect(result.suggested_name).to be_nil
  end
end
