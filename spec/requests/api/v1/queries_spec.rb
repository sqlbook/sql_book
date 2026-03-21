# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 queries', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Warehouse DB') }

  describe 'authentication' do
    it 'returns unauthorized when no session is present' do
      get "/api/v1/workspaces/#{workspace.id}/queries"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['status']).to eq('unauthorized')
    end
  end

  describe 'authorized operations' do
    before do
      sign_in(owner)
      data_source
    end

    it 'lists saved workspace queries' do
      create(:query, data_source:, saved: true, name: 'User count', query: 'SELECT COUNT(*) FROM public.users')
      create(:query, data_source:, saved: false, name: 'Draft query')

      get "/api/v1/workspaces/#{workspace.id}/queries"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')

      queries = response.parsed_body.dig('data', 'queries')
      expect(queries.map { |query| query['name'] }).to include('User count')
      expect(queries.map { |query| query['name'] }).not_to include('Draft query')
    end

    it 'runs a read-only workspace query' do
      query_result = ActiveRecord::Result.new(['count'], [[9]])
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [{ name: 'id', data_type: 'bigint' }]
            }
          ]
        }
      ]

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post "/api/v1/workspaces/#{workspace.id}/queries/run",
           params: { question: 'How many users do I have?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'sql')).to eq('SELECT COUNT(*) AS count FROM public.users')
      expect(response.parsed_body.dig('data', 'row_count')).to eq(1)
    end

    it 'saves a query to the library' do
      expect do
        post "/api/v1/workspaces/#{workspace.id}/queries",
             params: {
               name: 'User count',
               sql: 'SELECT COUNT(*) AS count FROM public.users',
               data_source_id: data_source.id
             },
             as: :json
      end.to change(Query, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'query', 'name')).to eq('User count')
      expect(Query.order(:id).last.saved).to be(true)
    end

    it 'renames a saved query' do
      query = create(:query, data_source:, saved: true, name: 'Users', query: 'SELECT * FROM public.users')

      patch "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}",
            params: { name: 'List of users' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'query', 'name')).to eq('List of users')
      expect(query.reload.name).to eq('List of users')
    end

    it 'deletes a saved query' do
      query = create(:query, data_source:, saved: true, name: 'Users', query: 'SELECT * FROM public.users')

      expect do
        delete "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}", as: :json
      end.to change(Query, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'deleted_query', 'name')).to eq('Users')
    end
  end

  describe 'role enforcement' do
    let(:read_only) { create(:user) }

    before do
      create(:member, workspace:, user: read_only, role: Member::Roles::READ_ONLY)
      sign_in(read_only)
      data_source
    end

    it 'allows read-only members to list saved queries' do
      create(:query, data_source:, saved: true, name: 'User count')

      get "/api/v1/workspaces/#{workspace.id}/queries"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
    end

    it 'blocks read-only members from running queries' do
      post "/api/v1/workspaces/#{workspace.id}/queries/run",
           params: { question: 'How many users do I have?' },
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
    end

    it 'blocks read-only members from saving queries' do
      post "/api/v1/workspaces/#{workspace.id}/queries",
           params: {
             name: 'User count',
             sql: 'SELECT COUNT(*) AS count FROM public.users',
             data_source_id: data_source.id
           },
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
    end

    it 'blocks read-only members from renaming queries' do
      query = create(:query, data_source:, saved: true, name: 'Users')

      patch "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}",
            params: { name: 'List of users' },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
    end

    it 'blocks read-only members from deleting queries' do
      query = create(:query, data_source:, saved: true, name: 'Users')

      delete "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
    end
  end
end
