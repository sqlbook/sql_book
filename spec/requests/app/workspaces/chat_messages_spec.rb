# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces chat messages', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }

  before do
    sign_in(user)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
  end

  describe 'GET /app/workspaces/:workspace_id/chat/messages' do
    it 'returns the active thread messages' do
      thread = ChatThread.active_for(workspace:, user:)
      message = create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'Hello'
      )

      get app_workspace_chat_messages_path(workspace), params: { thread_id: thread.id }

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['thread_id']).to eq(thread.id)
      expect(payload['messages'].map { |row| row['id'] }).to include(message.id)
    end

    it 'does not expose another workspace member thread messages' do
      teammate = create(:user)
      create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN, status: Member::Status::ACCEPTED)
      teammate_thread = create(:chat_thread, workspace:, created_by: teammate, title: 'Teammate private')
      create(
        :chat_message,
        chat_thread: teammate_thread,
        user: teammate,
        role: ChatMessage::Roles::USER,
        content: 'Private thread'
      )

      get app_workspace_chat_messages_path(workspace), params: { thread_id: teammate_thread.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'thread_id' => nil, 'messages' => [] })
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/messages' do
    it 'creates a basic message and assistant reply' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'Hello chat' }, as: :json
      end.to change(ChatMessage, :count).by(2)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
    end

    it 'returns member list details instead of count-only output' do
      teammate_user = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['role']).to eq('assistant')
      expect(assistant_message['content']).to include('tess@example.com')
      expect(assistant_message['content']).to include('Admin')
    end

    it 'keeps member detail follow-ups in member.list flow' do
      teammate_user = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'sure, but what are their names and details?'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['content']).to include('tess@example.com')
      expect(assistant_message['content']).to include('Role')
      expect(assistant_message['content']).to include('Status')
    end

    it 'creates a new thread with a generated title when thread_id is not provided' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'Invite my team mates' }, as: :json
      end.to change(ChatThread, :count).by(1)

      expect(response).to have_http_status(:ok)
      created_thread = ChatThread.order(:id).last
      expect(created_thread.title).to be_present
      expect(created_thread.title).not_to end_with('?')
    end

    it 'generates a human thread title for a SQL-first message' do
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return([
          {
            schema: 'public',
            tables: [
              {
                name: 'users',
                qualified_name: 'public.users',
                columns: [
                  { name: 'id', data_type: 'bigint' }
                ]
              }
            ]
          }
        ])
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(ActiveRecord::Result.new(['user_count'], [[3]]))
      create(:data_source, :postgres, workspace:, name: 'Staging App DB')

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'SELECT COUNT(*) AS user_count FROM public.users;' },
           as: :json

      expect(response).to have_http_status(:ok)
      created_thread = ChatThread.order(:id).last
      expect(created_thread.title).to be_present
      expect(created_thread.title).not_to match(/\ASELECT\b/i)
      expect(created_thread.title.downcase).to include('user')
    end

    it 'starts a staged data source setup flow instead of falling back to a capability summary' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can you help me add a data source?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.datasource_setup.ask_name')
      )
    end

    it 'collects PostgreSQL data source setup details in sensible stages and creates the source' do
      available_tables = [
        {
          schema: 'public',
          tables: [
            { name: 'users', qualified_name: 'public.users' },
            { name: 'accounts', qualified_name: 'public.accounts' }
          ]
        }
      ]
      validation_result = DataSources::ConnectionValidationService::Result.new(
        success?: true,
        available_tables:,
        checked_at: Time.zone.local(2026, 3, 21, 12, 0, 0),
        error_code: nil,
        message: nil
      )

      allow(DataSources::ConnectionValidationService).to receive(:new).and_return(
        instance_double(DataSources::ConnectionValidationService, call: validation_result)
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can you help me add a data source?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Call it Warehouse DB' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('host')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('database name')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('username')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('password')

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: [
               'Host is db.example.com, database name is warehouse,',
               'username is readonly, and password is super-secret'
             ].join(' ')
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('public.users')

      last_user_message = ChatThread.find(thread_id).chat_messages.where(role: ChatMessage::Roles::USER).order(:id).last
      expect(last_user_message.content).to include('[REDACTED]')
      expect(last_user_message.content).not_to include('super-secret')
      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'Use public.users' },
             as: :json
      end.to change { workspace.data_sources.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Warehouse DB')

      created_source = workspace.data_sources.order(:id).last
      expect(created_source.source_type).to eq('postgres')
      expect(created_source.name).to eq('Warehouse DB')
      expect(created_source.selected_tables).to eq(['public.users'])
    end

    it 'lets owners query a connected data source from chat' do
      create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[12]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'How many users do I have?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Warehouse DB')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('| count |')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('| 12 |')
    end

    it 'treats direct SQL as query.run even in a thread with recent query-library context' do
      create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['user_count'], [[3]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      thread = create(:chat_thread, workspace:, created_by: user, title: 'Query library')
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'show me my query library'
      )
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::ASSISTANT,
        content: 'Here are 2 saved queries',
        metadata: {
          result_data: {
            queries: [
              { id: 1, name: 'Users' },
              { id: 2, name: 'User count' }
            ]
          }
        }
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'SELECT COUNT(*) AS user_count FROM public.users;'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('Staging App DB')
      expect(assistant_content).to include('SELECT COUNT(*) AS user_count FROM public.users;')
      expect(assistant_content).to include('| user_count |')
      expect(assistant_content).not_to include('I can save this SQL as a query')
    end

    it 'serializes assistant markdown html for inline chat rendering' do
      create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[12]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Show me how many users I have' },
           as: :json

      expect(response).to have_http_status(:ok)
      assistant_message = response.parsed_body['messages'].last
      expect(assistant_message['content_html']).to include('<pre><code')
      expect(assistant_message['content_html']).to include('<table>')
      expect(assistant_message['content_html']).to include('<td>12</td>')
    end

    it 'saves the most recent chat query to the query library' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[12]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Show me how many users I have' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'Great, please save this query' },
             as: :json
      end.to change(Query, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('query library')

      saved_query = Query.order(:id).last
      expect(saved_query.saved).to be(true)
      expect(saved_query.data_source_id).to eq(data_source.id)
      expect(saved_query.query).to eq('SELECT COUNT(*) AS count FROM public.users')
      expect(saved_query.name).to eq('User count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('[User count](/app/workspaces/')
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include(
        %(href="/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{saved_query.id}")
      )
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include('class="chat-query-link"')
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include('target="_blank"')

      query_reference = ChatThread.find(thread_id).chat_query_references.recent_first.first
      expect(query_reference.saved_query_id).to eq(saved_query.id)
      expect(query_reference.current_name).to eq('User count')
      expect(query_reference.original_question).to eq('Show me how many users I have')
    end

    it 'generates a concise saved query name from the SQL shape instead of reusing the full prompt' do
      create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'first_name', data_type: 'text' },
                { name: 'last_name', data_type: 'text' },
                { name: 'email', data_type: 'text' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(
        %w[first_name last_name email],
        [['Bob', 'Smith', 'hello@sitelabs.ai']]
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'SELECT first_name, last_name, email FROM public.users' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'Nice, can you save that query for me please?' },
             as: :json
      end.to change(Query, :count).by(1)

      expect(response).to have_http_status(:ok)
      saved_query = Query.order(:id).last
      expect(saved_query.name).to eq('User names and email addresses')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('User names and email addresses')
    end

    it 'saves the most recent query when the user says save that for me' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['user_count'], [[3]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'SELECT COUNT(*) AS user_count FROM public.users;' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'Could you save that for me?' },
             as: :json
      end.to change(Query, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')

      saved_query = Query.order(:id).last
      expect(saved_query.data_source_id).to eq(data_source.id)
      expect(saved_query.name).to eq('User count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"User count"')
    end

    it 'renames a saved query from chat and carries the target query across the rename follow-up' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      recent_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Admins',
        query: 'SELECT * FROM public.admins',
        author: user,
        last_updated_by: user
      )
      target_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Users',
        query: 'SELECT * FROM public.users',
        author: user,
        last_updated_by: user
      )
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'saved_query_id' => recent_query.id,
        'saved_query_name' => recent_query.name
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'Can you rename my other query for me?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Users')

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: "Let's call it 'List of users'" },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(target_query.reload.name).to eq('List of users')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"List of users"')
    end

    it 'renames the most recently saved query when the user says to change it to a better name' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'how many users do I have',
        query: 'SELECT COUNT(*) AS row_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'saved_query_id' => saved_query.id,
        'saved_query_name' => saved_query.name,
        'sql' => saved_query.query,
        'data_source_id' => data_source.id,
        'data_source_name' => data_source.name
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'Thanks, that name is okay, but could you change it to User Count?'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(saved_query.reload.name).to eq('User Count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"User Count"')
    end

    it 'renames the recent saved query directly from a conversational follow-up without rerunning the query' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'saved_query_id' => saved_query.id,
        'saved_query_name' => saved_query.name,
        'sql' => saved_query.query,
        'data_source_id' => data_source.id,
        'data_source_name' => data_source.name
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'Actually do you think you could rename it to DB User Count?'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(saved_query.reload.name).to eq('DB User Count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"DB User Count"')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('Here’s what I found')
    end

    it 'renames the most recently saved query from a quoted follow-up without needing the word to' do
      create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['user_count'], [[3]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'SELECT COUNT(*) AS user_count FROM public.users;' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Can you save this query for me?' },
           as: :json

      saved_query = Query.order(:id).last
      expect(saved_query.name).to eq('User count')

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: "Nice, could you rename it 'User Count [Test]' please?"
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(saved_query.reload.name).to eq('User Count [Test]')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"User Count [Test]"')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('Here are')
    end

    it 'renames the recent saved query when the user confirms an assistant-proposed new name' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'saved_query_id' => saved_query.id,
        'saved_query_name' => saved_query.name,
        'sql' => saved_query.query,
        'data_source_id' => data_source.id,
        'data_source_name' => data_source.name
      )
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::ASSISTANT,
        content: "It’s currently called User count.\n\nIf you want, I can rename it to DB User Count now."
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'Yes please' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(saved_query.reload.name).to eq('DB User Count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"DB User Count"')
    end

    it 'renames a specifically named saved query when both the old and new names are quoted in one request' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      target_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Can you query in a way that also pulls their names and email addresses',
        query: 'SELECT first_name, last_name, email FROM public.users',
        author: user,
        last_updated_by: user
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: [
               "Can you rename the query 'Can you query in a way that also pulls their names and",
               "email addresses' to 'User names and emails'?"
             ].join(' ')
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(target_query.reload.name).to eq('User names and emails')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"User names and emails"')
    end

    it 'can still resolve an old saved query name after the query has been renamed once already' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      target_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'DB User Count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      create(
        :chat_query_reference,
        chat_thread: thread,
        data_source:,
        saved_query: target_query,
        sql: target_query.query,
        current_name: 'DB User Count',
        name_aliases: ['User count']
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: "Rename the query 'User count' to 'Total DB users'"
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(target_query.reload.name).to eq('Total DB users')
    end

    it 'resolves ordered query references from the most recent query list in the thread' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      first_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      second_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User names and emails',
        query: 'SELECT first_name, last_name, email FROM public.users',
        author: user,
        last_updated_by: user
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: "Here are 2 saved queries:\n\n- #{first_query.name}\n- #{second_query.name}",
        metadata: {
          result_data: {
            queries: [
              {
                id: first_query.id,
                name: first_query.name,
                data_source: { id: data_source.id, name: data_source.name }
              },
              {
                id: second_query.id,
                name: second_query.name,
                data_source: { id: data_source.id, name: data_source.name }
              }
            ]
          }
        }
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'Rename the first query to Total users'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(first_query.reload.name).to eq('Total users')
      expect(second_query.reload.name).to eq('User names and emails')
    end

    it 'can complete a rename after a saved-query list fallback once the user picks the first one' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      first_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      second_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'DB User Count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      create(
        :chat_query_reference,
        chat_thread: thread,
        data_source:,
        saved_query: first_query,
        sql: first_query.query,
        current_name: first_query.name
      )
      create(
        :chat_query_reference,
        chat_thread: thread,
        data_source:,
        saved_query: second_query,
        sql: second_query.query,
        current_name: second_query.name
      )
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: "Nice, could you rename it 'User Count [Test]' please?"
      )
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: "Here are 2 saved queries:\n\n- #{first_query.name}\n- #{second_query.name}",
        metadata: {
          result_data: {
            queries: [
              {
                id: first_query.id,
                name: first_query.name,
                data_source: { id: data_source.id, name: data_source.name }
              },
              {
                id: second_query.id,
                name: second_query.name,
                data_source: { id: data_source.id, name: data_source.name }
              }
            ]
          }
        }
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'the first one mf' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(first_query.reload.name).to eq('User Count [Test]')
      expect(second_query.reload.name).to eq('DB User Count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('"User Count [Test]"')
    end

    it 'requires confirmation before deleting a saved query from chat' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Users',
        query: 'SELECT * FROM public.users',
        author: user,
        last_updated_by: user
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Delete the saved query Users' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('requires_confirmation')
      action_request = ChatActionRequest.order(:id).last
      expect(action_request.action_type).to eq('query.delete')

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: action_request.chat_thread_id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(Query.exists?(query.id)).to be(false)
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Users')
      expect(query_reference_for(chat_thread_id: action_request.chat_thread_id, name: 'Users').saved_query_id).to be_nil
    end

    it 'deletes the query that was just listed when the user says delete that one' do
      thread = ChatThread.active_for(workspace:, user:)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      wrong_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Users',
        query: 'SELECT * FROM public.users',
        author: user,
        last_updated_by: user
      )
      target_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Can you query in a way that also pulls their names and email addresses',
        query: 'SELECT first_name, last_name, email FROM public.users',
        author: user,
        last_updated_by: user
      )
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'saved_query_id' => wrong_query.id,
        'saved_query_name' => wrong_query.name
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: "Here are 1 saved queries:\n\n- #{target_query.name}",
        metadata: {
          result_data: {
            queries: [
              {
                id: target_query.id,
                name: target_query.name,
                data_source: { id: data_source.id, name: data_source.name }
              }
            ]
          }
        }
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'Yes, delete that one' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('requires_confirmation')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include(target_query.name)

      action_request = ChatActionRequest.order(:id).last
      expect(action_request.action_type).to eq('query.delete')
      expect(action_request.payload['query_id']).to eq(target_query.id)
      expect(action_request.payload['query_name']).to eq(target_query.name)

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: action_request.chat_thread_id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(Query.exists?(target_query.id)).to be(false)
      expect(Query.exists?(wrong_query.id)).to be(true)
      expect(response.parsed_body.dig('messages', -1, 'content')).to include(target_query.name)
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('Users')
    end

    it 'lists saved queries from chat' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS count FROM public.users'
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Show my query library' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('User count')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Warehouse DB')
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include(
        %(href="/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{saved_query.id}")
      )
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include('class="chat-query-link"')
      expect(response.parsed_body.dig('messages', -1, 'content_html')).to include('target="_blank"')
    end

    it 'asks a clarifying question when more than one data source could answer a query' do
      create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      create(:data_source, :postgres, workspace:, name: 'CRM DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Show me how many users I have' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Warehouse DB')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('CRM DB')
    end

    it 'resumes a query clarification when the user answers with the chosen data source' do
      create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      create(:data_source, :postgres, workspace:, name: 'CRM DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[7]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Show me how many users I have' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Use Warehouse DB' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Warehouse DB')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('| 7 |')
    end

    it 'resumes a recent database query clarification before stale datasource setup state' do
      create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      thread = create(:chat_thread, workspace:, created_by: user, title: 'Users question')
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'How many users do I have?'
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: <<~TEXT
          I can check that, but I need to know what you mean by users:

          workspace members in Orange Inc, or
          user records in your connected database?
        TEXT
      )
      Chat::DataSourceSetupStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'next_step' => 'name'
      )

      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' },
                { name: 'email', data_type: 'text' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[12]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'Ah sorry, I mean in my connected database!' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Staging App DB')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('| 12 |')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('host, database name')
    end

    it 'uses schema guidance during table clarification follow-ups instead of falling back to datasource listing' do
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      thread = create(:chat_thread, workspace:, created_by: user, title: 'Users table clarification')
      Chat::QueryClarificationStateStore.new(workspace:, actor: user, chat_thread: thread).save(
        'question' => 'How many users do I have?',
        'step' => 'table',
        'data_source_id' => data_source.id,
        'candidate_tables' => [
          { 'qualified_name' => 'public.users', 'name' => 'users' },
          { 'qualified_name' => 'public.accounts', 'name' => 'accounts' }
        ]
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'Okay, well surely you can tell from the schema for the various tables?'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('public.users')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('public.accounts')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('data source(s) found')
    end

    it 'continues the database branch after a team answer with one connected data source' do
      create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      thread = create(:chat_thread, workspace:, created_by: user, title: 'Users follow-up')
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Who are my users?'
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: <<~TEXT
          Do you mean workspace members or user records in your connected database?

          If you mean your team/workspace members, I can list them.
          If you mean users in the data source, I can query the public.users table.
        TEXT
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'My team please'
      )
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: <<~TEXT
          Found 2 team members.

          Christopher Pattison (chris.pattison@protonmail.com) - Admin, Accepted
          Bob Smith (hello@sitelabs.ai) - Owner, Accepted
        TEXT
      )

      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'first_name', data_type: 'text' },
                { name: 'last_name', data_type: 'text' },
                { name: 'email', data_type: 'text' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(
        %w[first_name last_name email],
        [['Bob', 'Smith', 'hello@sitelabs.ai']]
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'And my users?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('Staging App DB')
      expect(assistant_content).to include('SELECT first_name, last_name, email FROM public.users')
      expect(assistant_content).to include('hello@sitelabs.ai')
      expect(assistant_content).not_to include('Which data source should I use')
    end

    it 'blocks data source setup for regular users but still allows querying' do
      owner = create(:user)
      limited_workspace = create(:workspace_with_owner, owner:)
      create(:member, workspace: limited_workspace, user:, role: Member::Roles::USER, status: Member::Status::ACCEPTED)
      create(:data_source, :postgres, workspace: limited_workspace, name: 'Warehouse DB')
      schema_groups = [
        {
          schema: 'public',
          tables: [
            {
              name: 'users',
              qualified_name: 'public.users',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      query_result = ActiveRecord::Result.new(['count'], [[5]])

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(schema_groups)
      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      post app_workspace_chat_messages_path(limited_workspace),
           params: { content: 'Can you help me add a data source?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('forbidden')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Admin')

      post app_workspace_chat_messages_path(limited_workspace),
           params: { content: 'Show me how many users I have' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('| 5 |')
    end

    it 'auto-executes low-risk write actions' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'rename workspace to New Name' }, as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(workspace.reload.name).to eq('New Name')
      expect(ChatActionRequest.order(:id).last.status).to eq(ChatActionRequest::Statuses::EXECUTED)
    end

    it 'creates a fresh low-risk write attempt per new user turn' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'rename workspace to Repeated Name' },
           as: :json
      thread_id = response.parsed_body['thread_id']
      first_request = ChatActionRequest.order(:id).last

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'rename workspace to Repeated Name' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Repeated Name')
      latest_request = ChatActionRequest.order(:id).last
      expect(latest_request.id).not_to eq(first_request.id)
      expect(latest_request.action_fingerprint).to eq(first_request.action_fingerprint)
      expect(latest_request.idempotency_key).not_to eq(first_request.idempotency_key)
    end

    it 'still executes writes when idempotency column is unavailable' do
      column_names_without_idempotency = ChatActionRequest.column_names - ['idempotency_key']
      allow(ChatActionRequest).to receive(:column_names).and_return(column_names_without_idempotency)

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { content: 'rename workspace to Fallback Name' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Fallback Name')
    end

    it 'extracts a clean target name for rename questions' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can you rename my workspace to Bumanarama?' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Bumanarama')
    end

    it 'creates a fresh confirmation attempt and supersedes the stale one' do
      thread = ChatThread.active_for(workspace:, user:)
      prior_message = create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'Old remove request'
      )
      stale_payload = {
        'email' => 'hello@sqlbook.com',
        'workspace_id' => workspace.id,
        'thread_id' => thread.id,
        'message_id' => prior_message.id
      }
      lifecycle = Chat::ActionRequestLifecycle.new(chat_thread: thread, actor: user)
      stale_fingerprint = lifecycle.action_fingerprint_for(action_type: 'member.remove', payload: stale_payload)
      stale_key = lifecycle.idempotency_key_for(action_fingerprint: stale_fingerprint, source_message: prior_message)
      stale_request = create(
        :chat_action_request,
        chat_thread: thread,
        chat_message: prior_message,
        source_message: prior_message,
        requested_by: user,
        action_type: 'member.remove',
        payload: stale_payload,
        action_fingerprint: stale_fingerprint,
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION,
        confirmation_expires_at: 1.minute.ago,
        idempotency_key: stale_key
      )

      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      allow(Chat::RuntimeService).to receive(:new).and_return(
        instance_double(
          Chat::RuntimeService,
          call: Chat::RuntimeService::Decision.new(
            assistant_message: 'Please confirm to proceed.',
            tool_calls: [
              Chat::RuntimeService::ToolCall.new(
                tool_name: 'member.remove',
                arguments: { 'email' => 'hello@sqlbook.com' }
              )
            ],
            missing_information: [],
            finalize_without_tools: false
          )
        )
      )

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id: thread.id, content: 'Could you remove hello@sqlbook.com please?' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('requires_confirmation')
      stale_request.reload
      latest_request = ChatActionRequest.order(:id).last
      expect(stale_request.superseded_at).to be_present
      expect(latest_request).not_to eq(stale_request)
      expect(latest_request.pending_confirmation?).to be(true)
      expect(latest_request.confirmation_expires_at).to be > Time.current
      expect(latest_request.idempotency_key).not_to eq(stale_request.idempotency_key)
      expect(latest_request.chat_message.content).to eq('Could you remove hello@sqlbook.com please?')
    end

    it 'creates a fresh auto-executed attempt on a new turn instead of replaying the old one' do
      thread = ChatThread.active_for(workspace:, user:)
      prior_message = create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'Old role update request'
      )
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      member = create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      stale_payload = {
        'member_id' => member.id,
        'email' => 'bob@example.com',
        'full_name' => 'Bob Smith',
        'role' => Member::Roles::ADMIN,
        'workspace_id' => workspace.id,
        'thread_id' => thread.id,
        'message_id' => prior_message.id
      }
      lifecycle = Chat::ActionRequestLifecycle.new(chat_thread: thread, actor: user)
      stale_fingerprint = lifecycle.action_fingerprint_for(action_type: 'member.update_role', payload: stale_payload)
      stale_key = lifecycle.idempotency_key_for(action_fingerprint: stale_fingerprint, source_message: prior_message)
      stale_request = create(
        :chat_action_request,
        chat_thread: thread,
        chat_message: prior_message,
        source_message: prior_message,
        requested_by: user,
        action_type: 'member.update_role',
        payload: stale_payload,
        action_fingerprint: stale_fingerprint,
        status: ChatActionRequest::Statuses::EXECUTED,
        result_payload: { 'user_message' => 'Old result' },
        executed_at: 20.minutes.ago,
        created_at: 20.minutes.ago,
        updated_at: 20.minutes.ago,
        idempotency_key: stale_key
      )

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id: thread.id, content: 'Promote Bob Smith to Admin' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      stale_request.reload
      expect(stale_request.status_name).to eq('executed')
      latest_request = ChatActionRequest.order(:id).last
      expect(latest_request).not_to eq(stale_request)
      expect(latest_request.action_fingerprint).to eq(stale_request.action_fingerprint)
      expect(latest_request.idempotency_key).not_to eq(stale_request.idempotency_key)
      promoted_member = workspace.members.joins(:user).find_by(users: { email: 'bob@example.com' })
      expect(promoted_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'does not replay a recent executed role update response from the same thread' do
      thread = ChatThread.active_for(workspace:, user:)
      prior_message = create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'Earlier promote request'
      )
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      member = create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      stale_payload = {
        'member_id' => member.id,
        'email' => 'bob@example.com',
        'full_name' => 'Bob Smith',
        'role' => Member::Roles::ADMIN,
        'workspace_id' => workspace.id,
        'thread_id' => thread.id,
        'message_id' => prior_message.id
      }
      lifecycle = Chat::ActionRequestLifecycle.new(chat_thread: thread, actor: user)
      stale_fingerprint = lifecycle.action_fingerprint_for(action_type: 'member.update_role', payload: stale_payload)
      stale_key = lifecycle.idempotency_key_for(action_fingerprint: stale_fingerprint, source_message: prior_message)
      create(
        :chat_action_request,
        chat_thread: thread,
        chat_message: prior_message,
        source_message: prior_message,
        requested_by: user,
        action_type: 'member.update_role',
        payload: stale_payload,
        action_fingerprint: stale_fingerprint,
        status: ChatActionRequest::Statuses::EXECUTED,
        result_payload: { 'user_message' => 'Bob Smith is now User.' },
        executed_at: 2.minutes.ago,
        created_at: 2.minutes.ago,
        updated_at: 2.minutes.ago,
        idempotency_key: stale_key
      )

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id: thread.id, content: 'Promote Bob Smith to Admin' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Admin')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to eq('Bob Smith is now User.')

      promoted_member = workspace.members.joins(:user).find_by(users: { email: 'bob@example.com' })
      expect(promoted_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'asks for required invite details before proposing an invite action' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'invite my team mates' }, as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload['messages'].last['role']).to eq('assistant')
      expect(payload['messages'].last['content']).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
      )
    end

    it 'asks for a role after invite follow-up provides name and email' do
      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Can I invite someone else?' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Their name is Bob Jenkins and their email is hello@sqlbook.com'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
      )
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).not_to be_present
    end

    it 'asks for name and role together when only the invite email is supplied' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Could you invite another for me please? hello@sqlbook.com' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_name_and_role')
      )
    end

    it 'extracts an inline invite role from the initial natural-language request' do
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: [
               'Can you invite a new admin called Christopher Pattison?',
               'Their email address is chris.pattison@protonmail.com'
             ].join(' ')
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'chris.pattison@protonmail.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'continues invite flow after a role follow-up in mixed context threads' do
      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Can I invite someone else?' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Their name is Bob Jenkins and their email is hello@sqlbook.com'
           },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Admin'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('hello@sqlbook.com')
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'honors natural role follow-up phrasing during invite setup and returns a single success reply' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Who are the members of my team?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Could you add another, called Tim Bananas, his email address is hello@sqlbook.com'
           },
           as: :json

      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Good question, he can be an Admin'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Admin')
      expect(response.parsed_body.dig('messages', -1, 'content')).not_to include('["')

      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'accepts a hedged role reply during an invite follow-up' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Could you invite another for me please? hello@sqlbook.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Chris Smith'
           },
           as: :json

      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'I think admin'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'asks for a role when first/last name and email are provided in a single follow-up message' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can I invite someone else?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Chris Smith, hello@sqlbook.com'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
      )

      invited_user = User.find_by(email: 'hello@sqlbook.com')
      expect(invited_user).not_to be_present
    end

    it 'uses recent removed-member context for invite-back requests but still requires a role' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user hello@sqlbook.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'I confirm' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Thanks could you invite him back actually?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        I18n.t('app.workspaces.chat.planner.member_invite_needs_role')
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'User' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('hello@sqlbook.com')
    end

    it 'answers invite role follow-ups from recent structured invite context' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can I invite someone else?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Chris Smith, hello@sqlbook.com' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'User' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'What role did you add him as?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'I invited Chris Smith as User. Their invitation is currently Pending.'
      )
    end

    it 'does not overwrite an existing user name when chat invites them with different names' do
      existing_user = create(:user, first_name: 'Robert', last_name: 'Jones', email: 'hello@sqlbook.com')

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Invite Chris Smith hello@sqlbook.com as admin' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(existing_user.reload.first_name).to eq('Robert')
      expect(existing_user.last_name).to eq('Jones')

      invited_member = workspace.members.find_by(user: existing_user)
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'answers recent invite follow-ups from current workspace state after acceptance' do
      invited_user = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Invite Chris Smith hello@sqlbook.com as admin' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      invited_member = workspace.members.find_by(user: invited_user)
      invited_member.update!(status: Member::Status::ACCEPTED)

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Have they accepted their invite?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'We’re talking about Chris Smith (hello@sqlbook.com). They are currently Accepted as Admin in this workspace.'
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Which user are we talking about here?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'We’re talking about Chris Smith (hello@sqlbook.com). They are currently Accepted as Admin in this workspace.'
      )
    end

    it 'asks for workspace name before proposing a rename action' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'rename workspace' }, as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload['messages'].last['role']).to eq('assistant')
      expect(payload['messages'].last['content']).to eq('Sure. What should the new workspace name be?')
    end

    it 'keeps high-risk member removal behind confirmation' do
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user bob@example.com' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload.dig('action_request', 'action_type')).to eq('member.remove')
    end

    it 'creates a pending removal action when user names the member instead of email' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can we delete the user Chris Smith?' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload.dig('action_request', 'action_type')).to eq('member.remove')
      expect(payload.dig('action_request', 'payload', 'email')).to eq('chris@example.com')
    end

    it 'auto-executes member role updates without confirmation' do
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { content: 'Promote Bob Smith to Admin' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(payload.dig('messages', -1, 'content')).to include('Bob Smith')
      expect(payload.dig('messages', -1, 'content')).to include('Admin')
      expect(ChatActionRequest.order(:id).last.status_name).to eq('executed')
      promoted_member = workspace.members.joins(:user).find_by(users: { email: 'bob@example.com' })
      expect(promoted_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'returns a deterministic capability summary for meta capability questions' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'What can you do for me?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')

      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('Team management')
      expect(assistant_content).to include('Data sources')
      expect(assistant_content).to include('Queries and query library')
      expect(assistant_content).not_to include('Invite a team member')
    end

    it 'does not leak stale invite follow-up prompts into unrelated off-scope questions' do
      thread = create(:chat_thread, workspace:, created_by: user)
      create(
        :chat_message,
        chat_thread: thread,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: I18n.t('app.workspaces.chat.planner.member_invite_needs_email_name_and_role')
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id: thread.id, content: 'Do you know anything about analytics?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')

      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('not as a general-purpose assistant')
      expect(assistant_content).to include('data source')
      expect(assistant_content).not_to include('first name')
      expect(assistant_content).not_to include('email address')
    end

    it 'explains its product scope for unrelated general questions' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'What day of the week is it?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')

      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('not as a general-purpose assistant')
      expect(assistant_content).to include('data source')
      expect(assistant_content).not_to include('first name')
      expect(assistant_content).not_to include('email address')
    end

    it 'uses the explicit role named in the user message when runtime payload is wrong' do
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      allow(Chat::RuntimeService).to receive(:new).and_return(
        instance_double(
          Chat::RuntimeService,
          call: Chat::RuntimeService::Decision.new(
            assistant_message: 'Updating the role now.',
            tool_calls: [
              Chat::RuntimeService::ToolCall.new(
                tool_name: 'member.update_role',
                arguments: {
                  'email' => 'bob@example.com',
                  'full_name' => 'Bob Smith',
                  'role' => Member::Roles::USER
                }
              )
            ],
            missing_information: [],
            finalize_without_tools: false
          )
        )
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Promote Bob Smith to Admin' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('Admin')

      promoted_member = workspace.members.joins(:user).find_by(users: { email: 'bob@example.com' })
      expect(promoted_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'verifies current member state against the workspace instead of stale executed action history' do
      thread = create(:chat_thread, workspace:, created_by: user)
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      member = create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )
      create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Bob Smith is now User.',
        metadata: {
          result_data: {
            member: {
              member_id: member.id,
              email: teammate.email,
              full_name: teammate.full_name,
              role: Member::Roles::USER,
              role_name: 'User',
              status: Member::Status::ACCEPTED,
              status_name: 'Accepted'
            }
          }
        }
      )
      create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        source_message: create(
          :chat_message,
          chat_thread: thread,
          user:,
          role: ChatMessage::Roles::USER,
          status: ChatMessage::Statuses::COMPLETED,
          content: 'Promote Bob Smith to User'
        ),
        action_type: 'member.update_role',
        payload: {
          'email' => teammate.email,
          'full_name' => teammate.full_name,
          'role' => Member::Roles::USER,
          'workspace_id' => workspace.id
        },
        action_fingerprint: 'member.update_role:stale',
        idempotency_key: 'member.update_role:stale:1',
        status: ChatActionRequest::Statuses::EXECUTED,
        result_payload: { 'user_message' => 'Bob Smith is now User.' },
        executed_at: 10.minutes.ago
      )

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id: thread.id,
             content: 'If you look at the team members you will see that Bob Smith is in fact an admin already'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')

      assistant_content = response.parsed_body.dig('messages', -1, 'content')
      expect(assistant_content).to include('Bob Smith')
      expect(assistant_content).to include('Admin')
      expect(assistant_content).not_to include('User')
    end

    it 'does not append duplicate confirmation copy when the assistant already asked to confirm' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      allow(Chat::RuntimeService).to receive(:new).and_return(
        instance_double(
          Chat::RuntimeService,
          call: Chat::RuntimeService::Decision.new(
            assistant_message: 'I can remove Chris Smith. Please confirm to proceed.',
            tool_calls: [
              Chat::RuntimeService::ToolCall.new(
                tool_name: 'member.remove',
                arguments: { 'email' => 'chris@example.com' }
              )
            ],
            missing_information: [],
            finalize_without_tools: false
          )
        )
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Remove Chris Smith' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('requires_confirmation')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'I can remove Chris Smith. Please confirm to proceed.'
      )
    end

    it 'rejects forbidden high-risk actions before confirmation for non-managing members' do
      owner = create(:user)
      restricted_workspace = create(:workspace_with_owner, owner:)
      create(
        :member,
        workspace: restricted_workspace,
        user:,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      create(
        :member,
        workspace: restricted_workspace,
        user: teammate,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      expect do
        post app_workspace_chat_messages_path(restricted_workspace),
             params: { content: 'Remove user bob@example.com' },
             as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('forbidden')
      message = response.parsed_body.dig('messages', -1, 'content')
      expect(message).to include(I18n.t('app.workspaces.chat.executor.allowed_roles.admin_or_owner'))
      expect(message).to include('remove')
    end

    it 'rejects member list requests for user-role members with allowed-role guidance' do
      owner = create(:user)
      restricted_workspace = create(:workspace_with_owner, owner:)
      create(
        :member,
        workspace: restricted_workspace,
        user:,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(restricted_workspace),
           params: { content: 'Show current team members' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('forbidden')
      message = response.parsed_body.dig('messages', -1, 'content')
      expect(message).to include(I18n.t('app.workspaces.chat.executor.allowed_roles.admin_or_owner'))
      expect(message).to include('team')
    end

    it 'allows written confirmation for a pending high-risk action' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user chris@example.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'I confirm' },
             as: :json
      end.to change { workspace.members.exists?(user: teammate) }.from(true).to(false)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('has been removed')
    end

    it 'allows written cancellation for a pending high-risk action' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user chris@example.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'cancel that' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('canceled')
      expect(workspace.members.exists?(user: teammate)).to be(true)
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq('Okay, I canceled that action.')
    end

    it 'rejects non-image attachments' do
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Please check this',
             images: [uploaded_text_file]
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
    end

    it 'rejects more than 6 images' do
      images = Array.new(7) { uploaded_image_file }
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Too many files',
             images:
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
    end

    it 'rejects images larger than 25MB' do
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Too large',
             images: [uploaded_large_image_file]
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
      expect(payload['message']).to eq('Images must be 25MB or smaller.')
    end

    it 'returns localized validation copy for Spanish locale' do
      user.update!(preferred_locale: 'es')

      post app_workspace_chat_messages_path(workspace), params: { content: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
      expect(payload['message']).to eq('Se requiere contenido del mensaje o al menos una imagen.')
    end

    it 'returns localized role and status labels for Spanish member list output' do
      user.update!(preferred_locale: 'es')
      teammate = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::READ_ONLY,
        status: Member::Status::PENDING
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'show current team members' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['content']).to include('Solo lectura')
      expect(assistant_message['content']).to include('Pendiente')
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/actions/:id/confirm' do
    it 'executes a pending rename action after confirmation' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        action_type: 'workspace.update_name',
        payload: { 'name' => 'Workspace Renamed Via Chat' },
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(workspace.reload.name).to eq('Workspace Renamed Via Chat')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::EXECUTED)
    end

    it 'rejects expired confirmation requests' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION,
        confirmation_expires_at: 1.minute.ago
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::PENDING_CONFIRMATION)
    end

    it 'returns forbidden when payload workspace scope does not match' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        action_type: 'workspace.update_name',
        payload: {
          'name' => 'Should Not Persist',
          'workspace_id' => workspace.id + 999,
          'thread_id' => thread.id,
          'message_id' => create(:chat_message, chat_thread: thread, user:).id
        },
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('forbidden')
      expect(workspace.reload.name).not_to eq('Should Not Persist')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::FORBIDDEN)
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/actions/:id/cancel' do
    it 'cancels a pending action request' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_cancel_path(workspace, action_request),
           params: { thread_id: thread.id },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::CANCELED)
    end
  end

  private

  def uploaded_image_file
    file = Tempfile.new(['chat-image', '.png'])
    file.binmode
    file.write("\x89PNG\r\n\x1A\n")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'image/png')
  end

  def uploaded_text_file
    file = Tempfile.new(['chat-text', '.txt'])
    file.write('not an image')
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/plain')
  end

  def uploaded_large_image_file
    file = Tempfile.new(['chat-image-large', '.png'])
    file.binmode
    file.write("\x89PNG\r\n\x1A\n")
    file.truncate(ChatMessage::MAX_IMAGE_SIZE + 1)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'image/png')
  end

  def query_reference_for(chat_thread_id:, name:)
    ChatQueryReference
      .where(chat_thread_id:)
      .where('current_name = ? OR name_aliases @> ?', name, [name].to_json)
      .order(updated_at: :desc, id: :desc)
      .first
  end
end
