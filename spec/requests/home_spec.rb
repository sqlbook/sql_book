# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    context 'when the user is not authenticated' do
      it 'renders the home page' do
        get '/'
        expect(response.status).to eq(200)
      end

      it 'uses spanish locale on first visit when browser language is spanish' do
        get '/', headers: { 'HTTP_ACCEPT_LANGUAGE' => 'es-ES,es;q=0.9' }

        expect(response.body).to include('lang="es"')
      end

      it 'falls back to english when browser language is unsupported' do
        get '/', headers: { 'HTTP_ACCEPT_LANGUAGE' => 'de-DE,de;q=0.9' }

        expect(response.body).to include('lang="en"')
      end
    end

    context 'when the user is authenticated' do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it 'redirects them to the data sources page' do
        get '/'
        expect(response).to redirect_to(app_workspaces_path)
      end
    end
  end
end
