# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces', type: :request do
  describe 'GET /app/workspaces' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    context 'when there are no workspaces' do
      it 'redirects to the new page' do
        get '/app/workspaces'
        expect(response).to redirect_to(new_app_workspace_path)
      end
    end

    context 'when there are workspaces' do
      let!(:workspace_1) { create(:workspace_with_owner, name: 'Workspace 1', owner: user) }
      let!(:workspace_2) { create(:workspace_with_owner, name: 'Workspace 1', owner: user) }

      it 'renders a list of workspaces' do
        get '/app/workspaces'

        expect(response.body).to have_selector('.workspace-card h4 a', text: workspace_1.name)
        expect(response.body).to have_selector('.workspace-card h4 a', text: workspace_2.name)
      end
    end
  end

  describe 'GET /app/workspaces/new' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'renders a form to enter a name' do
      get '/app/workspaces/new'
      expect(response.body).to include('id="name"')
    end

    it 'shows a welcome message' do
      get '/app/workspaces/new'
      expect(response.body).to include('Welcome to sqlbook')
    end

    context 'if the user already has workspaces' do
      before do
        create(:workspace_with_owner, owner: user)
      end

      it 'shows a boring message' do
        get '/app/workspaces/new'
        expect(response.body).to include('Create new workspace')
      end
    end
  end

  describe 'POST /app/workspaces' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    context 'when no name is provided' do
      it 'redirects back to the new page' do
        post '/app/workspaces'
        expect(response).to redirect_to(new_app_workspace_path)
      end
    end

    context 'when a name is provided' do
      let(:name) { 'My Workspace' }

      context 'and it is their first workspace' do
        it 'redirects them to create a data source' do
          post '/app/workspaces', params: { name: }
          expect(response).to redirect_to(new_app_workspace_data_source_path(Workspace.last))
        end
      end

      context 'and they have existing data sources' do
        before do
          create(:workspace_with_owner, owner: user)
        end

        it 'redirects them to the workspaces page' do
          post '/app/workspaces', params: { name: }
          expect(response).to redirect_to(app_workspaces_path)
        end
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    context 'when the workspace does not exist' do
      it 'renders the 404 page' do
        get "/app/workspace/#{workspace.id}"
        expect(response.status).to eq(404)
      end
    end

    context 'when the workspace exists' do
      it 'renders the show page' do
        get "/app/workspaces/#{workspace.id}"
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'PATCH /app/workspaces/:workspace_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'updates the workspace' do
      expect { patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' } }
        .to change { workspace.reload.name }.from(workspace.name).to('new_name')
    end

    it 'redirects to the general tab' do
      patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' }
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'general'))
    end
  end
end
