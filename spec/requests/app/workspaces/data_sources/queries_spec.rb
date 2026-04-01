# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources::Queries', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:owner) { user }

  before { sign_in(user) }

  describe 'GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries' do
    context 'when the data source does not exist' do
      it 'renders a 404 page' do
        get "/app/workspaces/#{workspace.id}/data_sources/92831093/queries"
        expect(response.status).to eq(404)
      end
    end

    context 'when the data source exists' do
      let(:data_source) { create(:data_source, workspace:) }

      it 'renders query breadcrumbs' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"

        expect(response.body).to have_selector(".breadcrumbs-link[href='#{app_workspaces_path}']", text: 'Workspaces')
        expect(response.body)
          .to have_selector(
            ".breadcrumbs-link[href='#{app_workspace_path(workspace)}']",
            text: workspace.name
          )
        expect(response.body)
          .to have_selector(".breadcrumbs-link[href='#{app_workspace_queries_path(workspace)}']", text: 'Query Library')
        expect(response.body).to have_selector('.breadcrumbs-current', text: 'Query')
      end

      it 'renders the query form' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"
        expect(response.body).to include('data-source-query')
      end

      it 'renders an unsaved draft query from params without requiring a persisted query id' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries",
            params: {
              query: 'SELECT COUNT(*) AS user_count FROM public.users;',
              name: 'User count'
            }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('SELECT COUNT(*) AS user_count FROM public.users;')
        expect(response.body).to include('User count')
      end
    end

    context 'when the data source is an external postgres source' do
      let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Warehouse DB') }
      let(:schema_groups) do
        [
          {
            schema: 'public',
            tables: [
              {
                name: 'orders',
                qualified_name: 'public.orders',
                columns: [
                  { name: 'id', data_type: 'bigint' },
                  { name: 'total', data_type: 'numeric' }
                ]
              }
            ]
          }
        ]
      end

      before do
        allow_any_instance_of(DataSources::Connectors::PostgresConnector)
          .to receive(:list_tables)
          .and_return(schema_groups)
      end

      it 'renders the datasource display name in the selector' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"

        expect(response.body).to include('Warehouse DB')
      end

      it 'renders the connector-aware schema browser' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"

        expect(response.body).to include(I18n.t('app.workspaces.queries.editor.schema_label'))
        expect(response.body).to include('public.orders')
        expect(response.body).to include('bigint')
        expect(response.body).to include('numeric')
      end
    end

    context 'when they do not own the data source' do
      let(:data_source) { create(:data_source) }

      it 'renders a 404 page' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:query' do
    let(:data_source) { create(:data_source, workspace:) }

    context 'when the query does not exist' do
      it 'redirects to query library with an error toast' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/234243242"
        expect(response).to redirect_to(app_workspace_queries_path(workspace))
        expect(flash[:toast]).to eq(
          type: 'error',
          title: I18n.t('toasts.workspaces.queries.missing.title'),
          body: I18n.t('toasts.workspaces.queries.missing.body')
        )
      end
    end

    context 'when the query exists' do
      let(:query) { create(:query, data_source:) }

      it 'renders the query form' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response.body).to include('data-source-query')
      end

      it 'sets the last_run_at timestamp' do
        expect { get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}" }
          .to change { query.reload.last_run_at.nil? }.from(true).to(false)
      end

      it 'shows a chat source link in settings when the current user can access the source thread' do
        thread = create(:chat_thread, workspace:, created_by: user, title: 'User count chat')
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
          result_message:,
          data_source:,
          saved_query: query,
          sql: query.query,
          current_name: query.name
        )

        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}?tab=settings"

        expect(response.body).to include('Chat source')
        expect(response.body).to include(
          app_workspace_path(workspace, thread_id: thread.id, anchor: "chat-message-#{result_message.id}")
        )
        expect(response.body).to include('target="_blank"')
      end

      it 'hides the chat source link when the current user cannot access the source thread' do
        teammate = create(:user)
        create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN, status: Member::Status::ACCEPTED)
        private_thread = create(:chat_thread, workspace:, created_by: teammate, title: 'Private source thread')
        create(
          :chat_query_reference,
          chat_thread: private_thread,
          data_source:,
          saved_query: query,
          sql: query.query,
          current_name: query.name
        )

        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}?tab=settings"

        expect(response.body).not_to include('Chat source')
      end
    end

    context 'when they do not own the query' do
      let(:data_source) { create(:data_source, workspace:) }
      let(:query) { create(:query) }

      it 'renders a 404 page' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/queries' do
    let(:data_source) { create(:data_source, workspace:) }

    it 'renders the delete action in the row options for deletable queries' do
      query = create(:query, data_source:, author: user, last_updated_by: user, saved: true, name: 'User count')

      get app_workspace_queries_path(workspace)

      expect(response.body).to include("Delete the #{query.name} query")
    end
  end

  describe 'POST /app/workspaces/:workspace_id/data_sources/:data_source_id/queries' do
    let(:data_source) { create(:data_source, workspace:) }
    let(:query_string) { 'SELECT * FROM sessions;' }

    it 'creates a new query' do
      expect do
        post("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries", params: { query: query_string })
      end
        .to change { Query.where(data_source_id: data_source.id).count }.by(1)
    end

    it 'sets the correct value of the query' do
      post("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries", params: { query: query_string })
      query = Query.where(data_source_id: data_source.id).last
      expect(query.query).to eq(query_string)
      expect(query.author).to eq(user)
    end

    it 'redirects to the new query' do
      post("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries", params: { query: query_string })
      query = Query.where(data_source_id: data_source.id).last
      expect(response).to redirect_to(app_workspace_data_source_query_path(workspace, data_source, query))
    end

    context 'when current user is read-only in the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

      it 'does not create a query' do
        request_params = { query: query_string }

        expect do
          post("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries", params: request_params)
        end.not_to change(Query, :count)
      end
    end
  end

  describe 'PUT /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:query' do
    let(:data_source) { create(:data_source, workspace:) }

    context 'when the query does not exist' do
      it 'renders a 404 page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/234243242"
        expect(response.status).to eq(404)
      end
    end

    context 'when not updating the name or the query' do
      let(:query) { create(:query, data_source:, query: 'SELECT * FROM page_views;') }
      let(:updated_query) { 'SELECT * FROM page_views LIMIT 1;' }

      it 'redirects to the query show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response).to redirect_to(app_workspace_data_source_query_path(workspace, data_source, query))
      end
    end

    context 'when updating the query' do
      let(:query) { create(:query, data_source:, query: 'SELECT * FROM page_views;') }
      let(:params) { { query: 'SELECT * FROM page_views LIMIT 1;' } }

      it 'updates the query' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}", params: }
          .to change { query.reload.query }
          .from('SELECT * FROM page_views;')
          .to('SELECT * FROM page_views LIMIT 1;')
      end

      it 'redirects to the query show page' do
        put("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}", params:)
        expect(response).to redirect_to(app_workspace_data_source_query_path(workspace, data_source, query))
      end

      it 'does not set the query as saved' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}", params: }
          .not_to change { query.reload.saved }
      end

      it 'updates the last updated by' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}", params: }
          .to change { query.reload.last_updated_by }
          .from(nil)
          .to(user)
      end

      context 'when current user is read-only in the workspace' do
        let(:owner) { create(:user) }

        before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

        it 'does not update the query' do
          expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}", params: }
            .not_to change { query.reload.query }
        end
      end
    end

    context 'when updating the name' do
      let(:query) { create(:query, data_source:, name: 'Query 1') }

      it 'updates the name' do
        expect do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
              params: { name: 'Query 2' }
        end
          .to change { query.reload.name }
          .from('Query 1')
          .to('Query 2')
      end

      it 'redirects to the query show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
            params: { name: 'Query 2' }
        expect(response).to redirect_to(app_workspace_data_source_query_path(workspace, data_source, query,
                                                                             tab: 'settings'))
      end

      it 'sets the query as saved' do
        expect do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
              params: { name: 'Query 2' }
        end
          .to change { query.reload.saved }
          .from(false)
          .to(true)
      end

      it 'updates the last updated by' do
        expect do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
              params: { name: 'Query 2' }
        end
          .to change { query.reload.last_updated_by }
          .from(nil)
          .to(user)
      end

      it 'can save a newly created draft query from the settings tab' do
        post "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries",
             params: { query: 'SELECT COUNT(*) AS user_count FROM public.users;' }
        draft_query = Query.order(:id).last

        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{draft_query.id}",
            params: { name: 'Count of users' }

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, draft_query, tab: 'settings')
        )
        expect(draft_query.reload.saved).to be(true)
        expect(draft_query.name).to eq('Count of users')
      end

      it 'reconciles matching unsaved chat query cards when a draft is saved from settings' do
        thread = create(:chat_thread, workspace:, created_by: user, title: 'User count chat')
        result_message = create(
          :chat_message,
          chat_thread: thread,
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: 'Here’s what I found from Staging App DB (1 row(s)):',
          metadata: {
            'query_card' => {
              'state' => 'unsaved',
              'question' => 'How many users do I have?',
              'sql' => 'SELECT COUNT(*) AS user_count FROM public.users;',
              'row_count' => 1,
              'columns' => ['user_count'],
              'rows' => [[3]],
              'suggested_name' => 'User count',
              'data_source' => {
                'id' => data_source.id,
                'name' => data_source.display_name
              }
            }
          }
        )
        create(
          :chat_query_reference,
          chat_thread: thread,
          result_message:,
          data_source:,
          saved_query: nil,
          sql: 'SELECT COUNT(*) AS user_count FROM public.users;',
          current_name: 'User count'
        )

        post "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries",
             params: { query: 'SELECT COUNT(*) AS user_count FROM public.users;' }
        draft_query = Query.order(:id).last

        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{draft_query.id}",
            params: { name: 'Count of users' }

        expect(result_message.reload.metadata.dig('query_card', 'state')).to eq('saved')
        expect(result_message.metadata.dig('query_card', 'saved_query', 'id')).to eq(draft_query.id)
        expect(result_message.metadata.dig('query_card', 'saved_query', 'name')).to eq('Count of users')
      end

      it 'redirects to the existing saved query when saving a draft with identical SQL' do
        existing_query = create(
          :query,
          data_source:,
          saved: true,
          name: 'User count',
          query: 'SELECT COUNT(*) AS user_count FROM public.users;'
        )
        draft_query = create(
          :query,
          data_source:,
          saved: false,
          query: existing_query.query
        )

        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{draft_query.id}",
            params: { name: 'Count of users' }

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, existing_query, tab: 'settings')
        )
        expect(flash[:toast]).to eq(
          type: 'info',
          title: I18n.t('toasts.workspaces.queries.already_saved.title'),
          body: I18n.t('toasts.workspaces.queries.already_saved.body', name: existing_query.name)
        )
        expect(draft_query.reload.saved).to be(false)
      end

      it 'reconciles matching unsaved chat query cards to the existing saved query on duplicate save' do
        thread = create(:chat_thread, workspace:, created_by: user, title: 'User count duplicate chat')
        result_message = create(
          :chat_message,
          chat_thread: thread,
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: 'Here’s what I found from Staging App DB (1 row(s)):',
          metadata: {
            'query_card' => {
              'state' => 'unsaved',
              'question' => 'How many users do I have?',
              'sql' => 'SELECT COUNT(*) AS user_count FROM public.users;',
              'row_count' => 1,
              'columns' => ['user_count'],
              'rows' => [[3]],
              'suggested_name' => 'User count',
              'data_source' => {
                'id' => data_source.id,
                'name' => data_source.display_name
              }
            }
          }
        )
        create(
          :chat_query_reference,
          chat_thread: thread,
          result_message:,
          data_source:,
          saved_query: nil,
          sql: 'SELECT COUNT(*) AS user_count FROM public.users;',
          current_name: 'User count'
        )
        existing_query = create(
          :query,
          data_source:,
          saved: true,
          name: 'User count',
          query: 'SELECT COUNT(*) AS user_count FROM public.users;'
        )
        draft_query = create(
          :query,
          data_source:,
          saved: false,
          query: existing_query.query
        )

        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{draft_query.id}",
            params: { name: 'Count of users' }

        expect(result_message.reload.metadata.dig('query_card', 'state')).to eq('saved')
        expect(result_message.metadata.dig('query_card', 'saved_query', 'id')).to eq(existing_query.id)
        expect(result_message.metadata.dig('query_card', 'saved_query', 'name')).to eq(existing_query.name)
      end
    end

    context 'when creating or updating a visualization' do
      let(:query) { create(:query, data_source:) }

      it 'creates a query-owned visualization' do
        expect do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/visualization",
              params: { chart_type: 'line' }
        end
          .to change { query.reload.visualization&.chart_type }
          .from(nil)
          .to('line')
      end

      it 'redirects to the query show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/visualization",
            params: { chart_type: 'line' }

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
        )
      end

      it 'updates the visualization configuration' do
        create(:query_visualization, query:, chart_type: 'line')

        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/visualization",
            params: {
              chart_type: 'line',
              other_config: { title: 'Revenue by month' },
              data_config: { dimension_key: 'month', value_key: 'revenue' }
            }

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
        )
        expect(query.reload.visualization.other_config['title']).to eq('Revenue by month')
        expect(query.visualization.data_config['dimension_key']).to eq('month')
      end

      it 'removes the visualization' do
        create(:query_visualization, query:, chart_type: 'line')
        expect do
          delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/visualization"
        end
          .to change { query.reload.visualization.present? }
          .from(true)
          .to(false)
      end
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/data_sources/:data_source_id/queries/:query' do
    let(:data_source) { create(:data_source, workspace:) }

    context 'when the query does not exist' do
      it 'renders a 404 page' do
        delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/234243242"
        expect(response.status).to eq(404)
      end
    end

    context 'when the query exists' do
      let!(:query) { create(:query, data_source:) }

      it 'redirects to the queries page' do
        delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response).to redirect_to(app_workspace_queries_path(workspace))
      end

      it 'destroys the query' do
        expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}" }
          .to change { Query.exists?(query.id) }.from(true).to(false)
      end

      context 'when current user has user role permissions' do
        let(:owner) { create(:user) }
        let(:query_author) { create(:user) }
        let!(:query) { create(:query, data_source:, author: query_author) }

        before { create(:member, workspace:, user:, role: Member::Roles::USER) }

        it 'does not destroy another users query' do
          expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}" }
            .not_to change { Query.exists?(query.id) }
        end
      end

      context 'when current user is read-only in the workspace' do
        let(:owner) { create(:user) }

        before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

        it 'does not destroy query' do
          expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}" }
            .not_to change { Query.exists?(query.id) }
        end
      end
    end
  end
end
