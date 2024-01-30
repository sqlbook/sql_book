# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources::Queries', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }

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

      it 'renders the query form' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries"
        expect(response.body).to include('data-source-query')
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
      it 'renders a 404 page' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/234243242"
        expect(response.status).to eq(404)
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
              params: { query: 'Query 2' }
        end
          .to change { query.reload.last_updated_by }
          .from(nil)
          .to(user)
      end
    end

    context 'when updating the chart type' do
      let(:query) { create(:query, data_source:) }

      it 'updates the query' do
        expect do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
              params: { chart_type: 'line' }
        end
          .to change { query.reload.chart_type }
          .from(nil)
          .to('line')
      end

      it 'redirects to the query show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
            params: { chart_type: 'line' }

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
        )
      end

      context 'when discarding the chart type' do
        let(:query) { create(:query, data_source:, chart_type: 'line') }

        it 'sets it to nil when the chart type is empty' do
          expect do
            put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
                params: { chart_type: '' }
          end
            .to change { query.reload.chart_type }
            .from('line')
            .to(nil)
        end

        it 'redirects to the query show page' do
          put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}",
              params: { chart_type: 'line' }

          expect(response).to redirect_to(
            app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
          )
        end
      end
    end

    context 'when updating the chart config' do
      let(:query) { create(:query, data_source:) }

      let(:params) do
        {
          **query.chart_config,
          title: 'My chart'
        }
      end

      it 'updates the query' do
        expect do
          put(
            "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/chart_config",
            params:
          )
        end
          .to change { query.reload.chart_config[:title] }
          .from('Title')
          .to('My chart')
      end

      it 'redirects to the query show page' do
        put("/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}/queries/#{query.id}/chart_config", params:)

        expect(response).to redirect_to(
          app_workspace_data_source_query_path(workspace, data_source, query, tab: 'visualization')
        )
      end
    end
  end
end
