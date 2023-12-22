# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::DataSources', type: :request do
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
        expect(response).to redirect_to(app_dashboard_index_path)
      end
    end
  end
end
