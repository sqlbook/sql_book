# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::DataSources', type: :request do
  describe 'GET /app/data_sources' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    context 'when there are no data sources' do
      it 'redirects to the new page' do
        get '/app/data_sources'
        expect(response).to redirect_to(new_app_data_source_path)
      end
    end

    context 'when there are data sources' do
      let!(:data_source_1) { create(:data_source, user:) }
      let!(:data_source_2) { create(:data_source, user:) }

      it 'renders a list of data_sources' do
        get '/app/data_sources'
        expect(response.body).to have_selector('.data-source-card h4 a', text: data_source_1.url)
        expect(response.body).to have_selector('.data-source-card h4 a', text: data_source_2.url)
      end
    end
  end

  describe 'GET /app/data_sources/new' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'renders a form to enter a url' do
      get '/app/data_sources/new'
      expect(response.body).to include('type="url"')
    end
  end

  describe 'POST /app/data_sources' do
    let(:user) { create(:user) }

    let(:data_sources_view_service) { instance_double('DataSourcesViewService') }

    before do
      sign_in(user)
      allow(DataSourcesViewService).to receive(:new).and_return(data_sources_view_service)
      allow(data_sources_view_service).to receive(:create!)
    end

    context 'when no url is provided' do
      it 'redirects back to the new page' do
        post '/app/data_sources'
        expect(response).to redirect_to(app_data_sources_path)
      end
    end

    context 'when a url is provided but it is invalid' do
      let(:url) { 'sdfsfdsf' }

      it 'redirects back to the new page' do
        post '/app/data_sources', params: { url: }
        expect(response).to redirect_to(app_data_sources_path)
      end

      it 'flashes a message' do
        post '/app/data_sources', params: { url: }
        expect(flash[:alert]).to eq('Url is not valid')
      end
    end

    context 'when a valid url is provided but it has been taken' do
      let(:url) { 'https://sqlbook.com' }

      before { create(:data_source, url:, user:) }

      it 'redirects back to the new page' do
        post '/app/data_sources', params: { url: }
        expect(response).to redirect_to(app_data_sources_path)
      end

      it 'flashes a message' do
        post '/app/data_sources', params: { url: }
        expect(flash[:alert]).to eq('Url has already been taken')
      end
    end

    context 'when a valid url is provided and it has not been taken' do
      let(:url) { 'https://sqlbook.com' }

      it 'redirects back to the new page' do
        post '/app/data_sources', params: { url: }
        expect(response).to redirect_to(app_data_source_set_up_index_path(DataSource.last.id))
      end

      it 'creates the views' do
        post '/app/data_sources', params: { url: }
        expect(data_sources_view_service).to have_received(:create!)
      end
    end
  end

  describe 'GET /app/data_sources/:id' do
    let(:user) { create(:user) }
    let(:data_source) { create(:data_source, user:) }

    before { sign_in(user) }

    context 'when the data source does not exist' do
      it 'renders the 404 page' do
        get '/app/data_sources/342342343223'
        expect(response.status).to eq(404)
      end
    end

    context 'when the data source exists' do
      it 'renders the show page' do
        get "/app/data_sources/#{data_source.id}"
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'PUT /app/data_sources/:id' do
    let(:user) { create(:user) }
    let(:data_source) { create(:data_source, verified_at: Time.current, user:) }

    before { sign_in(user) }

    context 'when the url is not provided' do
      it 'redirects to the show page' do
        put "/app/data_sources/#{data_source.id}"
        expect(response).to redirect_to(app_data_source_path(data_source))
      end
    end

    context 'when the provided url is invalid' do
      it 'redirects to the show page' do
        put "/app/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfdsfdsfds' }
        expect(response).to redirect_to(app_data_source_path(data_source))
      end

      it 'does not update the url' do
        expect { put "/app/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfdsfdsfds' } }
          .not_to change { data_source.reload.url }
      end

      it 'flashes a message' do
        put "/app/data_sources/#{data_source.id}", params: { url: 'dfsdfsdfdsfdsfds' }
        expect(flash[:alert]).to eq('Url is not valid')
      end
    end

    context 'when the provided url is valid' do
      it 'redirects to the show page' do
        put "/app/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' }
        expect(response).to redirect_to(app_data_source_path(data_source))
      end

      it 'updates the url' do
        expect { put "/app/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' } }
          .to change { data_source.reload.url }.from(data_source.url).to('https://valid-url.com')
      end

      it 'resets the verified_at' do
        expect { put "/app/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' } }
          .to change { data_source.reload.verified_at }.from(data_source.verified_at).to(nil)
      end
    end
  end

  describe 'DELETE /app/data_sources/:id' do
    let(:user) { create(:user) }
    let(:data_source) { create(:data_source, user:) }

    let(:data_sources_view_service) { instance_double('DataSourcesViewService') }

    before { sign_in(user) }

    before do
      allow(EventDeleteJob).to receive(:perform_later)
      allow(DataSourcesViewService).to receive(:new).and_return(data_sources_view_service)
      allow(data_sources_view_service).to receive(:destroy!)
    end

    it 'enqueues the delete job' do
      delete "/app/data_sources/#{data_source.id}"
      expect(EventDeleteJob).to have_received(:perform_later).with(data_source.external_uuid)
    end

    it 'destroys the views' do
      delete "/app/data_sources/#{data_source.id}"
      expect(data_sources_view_service).to have_received(:destroy!)
    end

    it 'deletes the data source' do
      expect { delete "/app/data_sources/#{data_source.id}" }
        .to change { DataSource.exists?(data_source.id) }.from(true).to(false)
    end
  end
end
