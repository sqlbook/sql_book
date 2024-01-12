# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'About', type: :request do
  describe 'GET /about' do
    it 'renders the about page' do
      get '/about'
      expect(response.status).to eq(200)
    end
  end
end
