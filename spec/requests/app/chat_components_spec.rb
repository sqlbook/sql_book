# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::ChatComponents', type: :request do
  describe 'GET /app/chat-components' do
    context 'when authenticated' do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it 'renders the chat components preview page' do
        get '/app/chat-components'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Chat Components')
        expect(response.body).to include('Thread Switcher / History Shell')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get '/app/chat-components'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end
  end
end
