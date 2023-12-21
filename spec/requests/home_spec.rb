# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    context 'when the user is not authenticated' do
      it 'renders the home page' do
        get '/'
        expect(response.status).to eq(200)
      end
    end

    context 'when the user is authenticated' do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it 'redirects them to the dashboard' do
        get '/'
        expect(response).to redirect_to(app_dashboard_index_path)
      end
    end
  end
end
