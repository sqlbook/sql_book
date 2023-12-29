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

    before { sign_in(user) }

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
        expect(response).to redirect_to(set_up_app_data_source_path(DataSource.last.id))
      end
    end
  end

  describe 'GET /app/data_sources/:id/set_up' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    context 'when there is no matching data source' do
      it 'renders the 404 page' do
        get '/app/data_sources/3353445/set_up'
        expect(response.status).to eq(404)
      end
    end

    context 'when there is a matching data source' do
      let(:data_source) { create(:data_source, user:) }

      it 'renders the set up page with the tracking code' do
        get "/app/data_sources/#{data_source.id}/set_up"
        expect(response.body).to include("uuid:&#39;#{data_source.external_uuid}&#39;")
      end
    end
  end
end
