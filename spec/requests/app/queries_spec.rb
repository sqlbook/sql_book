# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Queries', type: :request do
  describe 'GET /app/queries' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'renders the queries page' do
      get '/app/queries'
      expect(response.status).to eq(200)
    end
  end
end
