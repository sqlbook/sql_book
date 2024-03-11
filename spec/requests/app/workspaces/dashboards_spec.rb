# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Dashboards', type: :request do
  describe 'GET /app/workspaces/:workspace_id/dashboards' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    context 'when there are no data soures' do
      it 'redirects to create one' do
        get "/app/workspaces/#{workspace.id}/dashboards"
        expect(response).to redirect_to(new_app_workspace_data_source_path(workspace))
      end
    end

    context 'when there are data sources' do
      let!(:data_source) { create(:data_source, workspace:) }

      context 'and there are no dashboards' do
        it 'returns an empty state' do
          get "/app/workspaces/#{workspace.id}/dashboards"
          expect(response.body).to include('Any dashboards you&apos;ve created will be available here')
        end
      end

      context 'and there are dashboards' do
        let!(:data_source) { create(:data_source, workspace:) }

        let!(:dashboard_1) { create(:dashboard, author: user, name: 'Foo', workspace:) }
        let!(:dashboard_2) { create(:dashboard, author: user, name: 'Bar', workspace:) }
        let!(:dashboard_3) { create(:dashboard, author: user, name: 'Baz', workspace:) }
        let!(:dashboard_4) { create(:dashboard, author: user, name: 'food', workspace:) }
        let!(:dashboard_5) { create(:dashboard, author: user, name: 'barry', workspace:) }
        let!(:dashboard_6) { create(:dashboard, author: user, name: 'should not show', workspace:) }

        it 'renders a list of dashboards' do
          get "/app/workspaces/#{workspace.id}/dashboards"

          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_1.name)
          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_2.name)
          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_3.name)
          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_4.name)
          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_5.name)
          expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_6.name)
        end

        context 'when a search param is provided' do
          it 'returns the results with the matching names' do
            get "/app/workspaces/#{workspace.id}/dashboards", params: { search: 'foo' }

            expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_1.name)
            expect(response.body).to have_selector('.dashboards-table .name', text: dashboard_4.name)

            expect(response.body).not_to have_selector('.dashboards-table .name', text: dashboard_2.name)
            expect(response.body).not_to have_selector('.dashboards-table .name', text: dashboard_3.name)
            expect(response.body).not_to have_selector('.dashboards-table .name', text: dashboard_5.name)
            expect(response.body).not_to have_selector('.dashboards-table .name', text: dashboard_6.name)
          end
        end
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/dashboards/new' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'renders a form to enter a url' do
      get "/app/workspaces/#{workspace.id}/dashboards/new"
      expect(response.body).to include('id="name"')
    end

    it 'shows some instructions to create a dashboard' do
      get "/app/workspaces/#{workspace.id}/dashboards/new"
      expect(response.body).to include('Please enter the name of your dashboard')
    end
  end

  describe 'POST /app/workspaces/:workspace_id/dashboards' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before do
      sign_in(user)
    end

    context 'when no name is provided' do
      it 'redirects back to the new page' do
        post "/app/workspaces/#{workspace.id}/dashboards"
        expect(response).to redirect_to(new_app_workspace_dashboard_path(workspace))
      end
    end

    context 'when a name is provided' do
      it 'creates the dashboard' do
        expect { post "/app/workspaces/#{workspace.id}/dashboards", params: { name: 'My dashboard' } }
          .to change { workspace.reload.dashboards.size }.by(1)
      end

      it 'redirects to the dashboard' do
        post "/app/workspaces/#{workspace.id}/dashboards", params: { name: 'My dashboard' }
        expect(response).to redirect_to(app_workspace_dashboard_path(workspace, workspace.dashboards.last))
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/dashboards/:dashboard_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }
    let(:dashboard) { create(:dashboard, workspace:, author: user) }

    before do
      sign_in(user)
    end

    context 'when the dashboard does not exist' do
      it 'renders the 404 page' do
        get "/app/workspace/#{workspace.id}/dashboards/342342343223"
        expect(response.status).to eq(404)
      end
    end

    context 'when the dashboard exists' do
      it 'renders the show page' do
        get "/app/workspaces/#{workspace.id}/dashboards/#{dashboard.id}"
        expect(response.status).to eq(200)
      end
    end
  end
end
