# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Dashboards', type: :request do
  describe 'GET /app/dashboard' do
    context 'when the user is not authenticated' do
      it 'redirects them to the home page' do
        get '/app/dashboard'
        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when the user is authenticated' do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it 'renders the dashboard' do
        get '/app/dashboard'
        expect(response.status).to eq(200)
      end
    end
  end
end
