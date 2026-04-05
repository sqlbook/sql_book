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
        expect(response.body).to include('data-controller="query-editor query-side-panel"')
        expect(response.body).to include('data-query-side-panel-default-open-value="false"')
        expect(response.body).to include('query-editor-page side-panel-layout--closed')
        expect(response.body).to include(app_workspace_query_editor_run_path(workspace))
        expect(response.body).to include(app_workspace_query_editor_save_path(workspace))
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
        expect(response.body).to include('data-controller="query-editor query-side-panel"')
        expect(response.body).to include('data-query-side-panel-default-open-value="true"')
        expect(response.body).to include('query-editor-page side-panel-layout--open')
        expect(response.body).to include(query.name)
        expect(response.body).to include(I18n.t('app.workspaces.queries.editor.open_details_aria'))
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

        expect(response.body).to include(
          app_workspace_path(workspace, thread_id: thread.id, anchor: "chat-message-#{result_message.id}")
        )
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

        expect(response.body).not_to include("thread_id=#{private_thread.id}")
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
