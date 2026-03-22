# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate limiting', type: :request do
  let(:ip_headers) { { 'REMOTE_ADDR' => '203.0.113.10' } }

  before do
    ENV['ENABLE_RATE_LIMITING_IN_TESTS'] = '1'
    Rack::Attack.enabled = true
  end

  after do
    ENV.delete('ENABLE_RATE_LIMITING_IN_TESTS')
  end

  it 'throttles repeated login code requests by IP' do
    user = create(:user, email: 'rate-limit@example.com')
    allow_any_instance_of(OneTimePasswordService).to receive(:create!).and_return(true)

    5.times do
      get '/auth/login/new', params: { email: user.email }, headers: ip_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    get '/auth/login/new', params: { email: user.email }, headers: ip_headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include(I18n.t('rate_limits.messages.auth'))
  end

  it 'throttles repeated chat message submissions per authenticated user' do
    user = create(:user)
    workspace = create(:workspace_with_owner, owner: user)
    sign_in(user)

    5.times do
      post app_workspace_chat_messages_path(workspace), params: { content: 'hello' }, as: :json, headers: ip_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post app_workspace_chat_messages_path(workspace), params: { content: 'hello again' }, as: :json, headers: ip_headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body['error_code']).to eq('rate_limited')
    expect(response.parsed_body['message']).to eq(I18n.t('rate_limits.messages.chat'))
  end

  it 'throttles repeated API query runs per authenticated user' do
    owner = create(:user)
    workspace = create(:workspace_with_owner, owner:)
    data_source = create(:data_source, :postgres, workspace:)
    sign_in(owner)

    allow_any_instance_of(DataSources::Connectors::PostgresConnector)
      .to receive(:list_tables)
      .and_return([{ schema: 'public', tables: [{ name: 'users', qualified_name: 'public.users', columns: [] }] }])
    allow_any_instance_of(DataSources::Connectors::PostgresConnector)
      .to receive(:execute_readonly)
      .and_return(ActiveRecord::Result.new(['count'], [[3]]))

    5.times do
      post "/api/v1/workspaces/#{workspace.id}/queries/run",
           params: { question: 'How many users do I have?', data_source_id: data_source.id },
           as: :json,
           headers: ip_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post "/api/v1/workspaces/#{workspace.id}/queries/run",
         params: { question: 'How many users do I have?', data_source_id: data_source.id },
         as: :json,
         headers: ip_headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body['error_code']).to eq('rate_limited')
    expect(response.parsed_body['message']).to eq(I18n.t('rate_limits.messages.query'))
  end

  it 'throttles repeated data source validation requests per authenticated user' do
    owner = create(:user)
    workspace = create(:workspace_with_owner, owner:)
    sign_in(owner)

    validation_result = DataSources::ConnectionValidationService::Result.new(
      success?: true,
      available_tables: [],
      checked_at: Time.zone.local(2026, 3, 22, 10, 0, 0),
      error_code: nil,
      message: nil
    )
    validation_service = instance_double(DataSources::ConnectionValidationService, call: validation_result)
    allow(DataSources::ConnectionValidationService).to receive(:new).and_return(validation_service)

    10.times do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: 'postgres',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           },
           headers: ip_headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
         params: {
           name: 'Warehouse DB',
           database_type: 'postgres',
           host: 'db.example.com',
           port: 5432,
           database_name: 'warehouse',
           username: 'readonly',
           password: 'secret'
         },
         headers: ip_headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include(I18n.t('rate_limits.messages.data_source'))
  end
end
