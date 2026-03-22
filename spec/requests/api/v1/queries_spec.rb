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

    it 'includes chat source provenance when the requester can access the source thread' do
      query = create(:query, data_source:, saved: true, name: 'User count', query: 'SELECT COUNT(*) FROM public.users')
      thread = create(:chat_thread, workspace:, created_by: owner, title: 'User count chat')
      source_message = create(:chat_message, chat_thread: thread, user: owner, content: 'How many users do I have?')
      result_message = create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Found 3 users.'
      )
      create(
        :chat_query_reference,
        chat_thread: thread,
        source_message:,
        result_message:,
        data_source:,
        saved_query: query,
        original_question: 'How many users do I have?',
        sql: query.query,
        current_name: query.name
      )

      get "/api/v1/workspaces/#{workspace.id}/queries"

      expect(response).to have_http_status(:ok)
      serialized_query = response.parsed_body.dig('data', 'queries').find { |row| row['id'] == query.id }
      expect(serialized_query['chat_source']).to include(
        'thread_id' => thread.id,
        'message_id' => result_message.id
      )
      expect(serialized_query['chat_source']['path']).to include("thread_id=#{thread.id}")
      expect(serialized_query['chat_source']['path']).to include("chat-message-#{result_message.id}")
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

    it 'returns the existing saved query instead of creating an exact duplicate' do
      existing_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS count FROM public.users',
        author: owner,
        last_updated_by: owner
      )

      expect do
        post "/api/v1/workspaces/#{workspace.id}/queries",
             params: {
               name: 'User count copy',
               sql: ' SELECT   COUNT(*) AS count FROM public.users; ',
               data_source_id: data_source.id
             },
             as: :json
      end.not_to change(Query, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('already_saved')
      expect(response.parsed_body.dig('data', 'query', 'id')).to eq(existing_query.id)
      expect(existing_query.reload.name).to eq('User count')
    end

    it 'returns a validation error when an auto-generated name collides with a different saved query' do
      existing_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users WHERE super_admin = true',
        author: owner,
        last_updated_by: owner
      )

      expect do
        post "/api/v1/workspaces/#{workspace.id}/queries",
             params: {
               sql: 'SELECT COUNT(*) AS user_count FROM public.users',
               question: 'How many users do I have?',
               data_source_id: data_source.id
             },
             as: :json
      end.not_to change(Query, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(response.parsed_body['error_code']).to eq('generated_name_conflict')
      expect(response.parsed_body.dig('data', 'proposed_name')).to eq('User count')
      expect(response.parsed_body.dig('data', 'conflicting_query', 'id')).to eq(existing_query.id)
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

    it 'updates a saved query SQL and name atomically' do
      query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: owner,
        last_updated_by: owner
      )

      patch "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}",
            params: {
              sql: <<~SQL.squish,
                SELECT super_admin, COUNT(*) AS user_count
                FROM public.users
                GROUP BY super_admin
                ORDER BY super_admin
              SQL
              name: 'User count by super admin status'
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'update_outcome')).to eq('updated')
      expect(query.reload.name).to eq('User count by super admin status')
      expect(query.query).to include('GROUP BY super_admin')
      expect(query.query_fingerprint).to be_present
    end

    it 'returns a validation error when an update would collide with another saved query fingerprint' do
      existing_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: owner,
        last_updated_by: owner
      )
      query_to_update = create(
        :query,
        data_source:,
        saved: true,
        name: 'User names',
        query: 'SELECT first_name, last_name FROM public.users',
        author: owner,
        last_updated_by: owner
      )

      patch "/api/v1/workspaces/#{workspace.id}/queries/#{query_to_update.id}",
            params: {
              sql: 'SELECT COUNT(*) AS user_count FROM public.users'
            },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(response.parsed_body['error_code']).to eq('duplicate_saved_query')
      expect(response.parsed_body.dig('data', 'conflicting_query', 'id')).to eq(existing_query.id)
      expect(query_to_update.reload.name).to eq('User names')
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

  describe 'chat source privacy' do
    let(:teammate) { create(:user) }

    before do
      sign_in(teammate)
      create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN, status: Member::Status::ACCEPTED)
    end

    it 'omits chat source when the requester cannot access the source thread' do
      query = create(:query, data_source:, saved: true, name: 'User count', query: 'SELECT COUNT(*) FROM public.users')
      thread = create(:chat_thread, workspace:, created_by: owner, title: 'Private source thread')
      create(
        :chat_query_reference,
        chat_thread: thread,
        data_source:,
        saved_query: query,
        current_name: query.name,
        sql: query.query
      )

      get "/api/v1/workspaces/#{workspace.id}/queries"

      expect(response).to have_http_status(:ok)
      serialized_query = response.parsed_body.dig('data', 'queries').find { |row| row['id'] == query.id }
      expect(serialized_query).not_to have_key('chat_source')
    end
  end
end
