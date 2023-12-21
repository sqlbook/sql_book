# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Signouts', type: :request do
  describe 'GET /auth/signout' do
    it 'redirects them to the home page' do
      get '/auth/signout'
      expect(response).to redirect_to(root_path)
    end
  end
end
