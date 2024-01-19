# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::DataSources::SetUp', type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe 'GET /app/data_sources/:data_source_id/set_up' do
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

    context 'when the verification has failed' do
      let(:data_source) { create(:data_source, user:) }

      it 'renders the failure message' do
        get "/app/data_sources/#{data_source.id}/set_up?verifying=true&verification_attempt=5"
        expect(response.body).to include('We were unable to verify your installation')
      end
    end

    context 'when the verification is pending' do
      let(:data_source) { create(:data_source, user:) }

      it 'renders the pending message' do
        get "/app/data_sources/#{data_source.id}/set_up?verifying=true"
        expect(response.body).to include('Verifying installation..')
      end
    end

    context 'when the data source is already verified' do
      let(:data_source) { create(:data_source, user:, verified_at: Time.current) }

      it 'redirecs to the data source' do
        get "/app/data_sources/#{data_source.id}/set_up"
        expect(response.body).to redirect_to(app_data_sources_path)
      end
    end
  end
end
