# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources', type: :request do
  describe 'GET /app/workspaces/:workspace_id/data_sources' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    context 'when there are no data sources' do
      it 'redirects to the new page' do
        get "/app/workspaces/#{workspace.id}/data_sources"
        expect(response).to redirect_to(new_app_workspace_data_source_path(workspace))
      end
    end

    context 'when there are data sources' do
      let!(:data_source_1) { create(:data_source, workspace:) }
      let!(:data_source_2) { create(:data_source, workspace:) }

      it 'renders a list of data_sources' do
        get "/app/workspaces/#{workspace.id}/data_sources"

        expect(response.body).to have_selector('.data-source-card h4 a', text: data_source_1.url)
        expect(response.body).to have_selector('.data-source-card h4 a', text: data_source_2.url)
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/data_sources/new' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'renders a form to enter a url' do
      get "/app/workspaces/#{workspace.id}/data_sources/new"
      expect(response.body).to include('type="url"')
    end

    it 'shows a welcome message' do
      get "/app/workspaces/#{workspace.id}/data_sources/new"
      expect(response.body).to include('Create your first data source')
    end

    context 'if the user already has data sources' do
      before do
        create(:data_source, workspace:)
      end

      it 'shows a boring message' do
        get "/app/workspaces/#{workspace.id}/data_sources/new"
        expect(response.body).to include('data source')
      end
    end
  end

  describe 'POST /app/workspaces/:workspace_id/data_sources' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before do
      sign_in(user)
    end

    context 'when no url is provided' do
      it 'redirects back to the new page' do
        post "/app/workspaces/#{workspace.id}/data_sources"
        expect(response).to redirect_to(app_workspace_data_sources_path(workspace))
      end
    end

    context 'when a url is provided but it is invalid' do
      let(:url) { 'sdfsfdsf' }

      it 'redirects back to the new page' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: }
        expect(response).to redirect_to(app_workspace_data_sources_path(workspace))
      end

      it 'flashes a message' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: }
        expect(flash[:alert]).to eq('Url is not valid')
      end
    end

    context 'when a valid url is provided but it has been taken' do
      let(:url) { 'https://sqlbook.com' }

      before { create(:data_source, url:) }

      it 'redirects back to the new page' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: }
        expect(response).to redirect_to(app_workspace_data_sources_path(workspace))
      end

      it 'flashes a message' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: }
        expect(flash[:alert]).to eq('Url has already been taken')
      end
    end

    context 'when a valid url is provided and it has not been taken' do
      let(:url) { 'https://sqlbook.com' }

      it 'redirects to the set up page' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: }
        expect(response).to redirect_to(app_workspace_data_source_set_up_index_path(workspace, DataSource.last.id))
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/data_sources/:data_source_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }
    let(:data_source) { create(:data_source, workspace:) }

    before { sign_in(user) }

    context 'when the data source does not exist' do
      it 'renders the 404 page' do
        get "/app/workspace/#{workspace.id}/data_sources/342342343223"
        expect(response.status).to eq(404)
      end
    end

    context 'when the data source exists' do
      it 'renders the show page' do
        get "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}"
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'PUT /app/workspaces/:workspace_id/data_sources/:id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }
    let(:data_source) { create(:data_source, workspace:, verified_at: Time.current) }

    before { sign_in(user) }

    context 'when the url is not provided' do
      it 'redirects to the show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}"
        expect(response).to redirect_to(app_workspace_data_source_path(workspace, data_source))
      end
    end

    context 'when the provided url is invalid' do
      it 'redirects to the show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfds' }
        expect(response).to redirect_to(app_workspace_data_source_path(workspace, data_source))
      end

      it 'does not update the url' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfds' } }
          .not_to change { data_source.reload.url }
      end

      it 'flashes a message' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfds' }
        expect(flash[:alert]).to eq('Url is not valid')
      end
    end

    context 'when the provided url is valid' do
      it 'redirects to the show page' do
        put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' }
        expect(response).to redirect_to(app_workspace_data_source_path(workspace, data_source))
      end

      it 'updates the url' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' } }
          .to change { data_source.reload.url }.from(data_source.url).to('https://valid-url.com')
      end

      it 'resets the verified_at' do
        expect { put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' } }
          .to change { data_source.reload.verified_at }.from(data_source.verified_at).to(nil)
      end
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/data_sources/:data_source_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }
    let(:data_source) { create(:data_source, workspace:) }

    before do
      sign_in(user)

      # Create 3 other members
      create(:member, workspace:)
      create(:member, workspace:)
      create(:member, workspace:)

      allow(DataSourceMailer).to receive(:destroy).and_call_original
    end

    it 'deletes the data source' do
      expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}" }
        .to change { DataSource.exists?(data_source.id) }.from(true).to(false)
    end

    it 'sends a mailer to every member in that workspace' do
      delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}"
      expect(DataSourceMailer).to have_received(:destroy).exactly(4).times
    end

    context 'when the data source has some data' do
      before do
        create(:click, data_source_uuid: data_source.external_uuid)
        create(:page_view, data_source_uuid: data_source.external_uuid)
        create(:page_view, data_source_uuid: data_source.external_uuid)
        create(:page_view, data_source_uuid: data_source.external_uuid)
        create(:session, data_source_uuid: data_source.external_uuid)
      end

      it 'enqueues the delete job' do
        delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}"
        expect(ActiveRecord::DestroyAssociationAsyncJob).to have_been_enqueued.exactly(3).times
      end
    end
  end
end
