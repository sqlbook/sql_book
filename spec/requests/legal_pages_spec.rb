# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legal pages', type: :request do
  describe 'GET /terms-of-service' do
    it 'renders the terms page' do
      get '/terms-of-service'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Terms of Service')
    end
  end

  describe 'GET /privacy-policy' do
    it 'renders the privacy page' do
      get '/privacy-policy'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Privacy Policy')
    end
  end

  describe 'footer links' do
    it 'renders legal page links and current server year' do
      get '/'

      expect(response.body).to include('/terms-of-service')
      expect(response.body).to include('/privacy-policy')
      expect(response.body).to include(Time.current.year.to_s)
    end
  end

  describe 'signup terms link' do
    it 'links to terms of service page' do
      get '/auth/signup'

      expect(response.body).to include('/terms-of-service')
    end
  end
end
