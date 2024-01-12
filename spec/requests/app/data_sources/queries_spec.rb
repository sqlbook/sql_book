# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::DataSources::Queries', type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe 'GET /app/data_sources/:data_source/queries' do
    context 'when the data source does not exist' do
      it 'renders a 404 page' do
        get '/app/data_sources/92831093/queries'
        expect(response.status).to eq(404)
      end
    end

    context 'when the data source exists' do
      let(:data_source) { create(:data_source, user:) }

      it 'renders the query form' do
        get "/app/data_sources/#{data_source.id}/queries"
        expect(response.body).to include('data-source-query')
      end
    end

    context 'when they do not own the data source' do
      let(:other_user) { create(:user) }
      let(:data_source) { create(:data_source, user: other_user) }

      it 'renders a 404 page' do
        get '/app/data_sources/92831093/queries'
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'GET /app/data_sources/:data_source/queries/:query' do
    let(:data_source) { create(:data_source, user:) }

    context 'when the query does not exist' do
      it 'renders a 404 page' do
        get "/app/data_sources/#{data_source.id}/queries/234243242"
        expect(response.status).to eq(404)
      end
    end

    context 'when the query exists' do
      let(:query) { create(:query, data_source:) }

      it 'renders the query form' do
        get "/app/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response.body).to include('data-source-query')
      end
    end

    context 'when they do not own the query' do
      let(:other_user) { create(:user) }
      let(:data_source) { create(:data_source, user: other_user) }
      let(:query) { create(:query, data_source:) }

      it 'renders a 404 page' do
        get "/app/data_sources/#{data_source.id}/queries/#{query.id}"
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'POST /app/data_sources/:data_source/queries' do
    let(:data_source) { create(:data_source, user:) }
    let(:query_string) { 'SELECT * FROM sessions;' }

    it 'creates a new query' do
      expect { post("/app/data_sources/#{data_source.id}/queries", params: { query: query_string }) }
        .to change { Query.where(data_source_id: data_source.id).count }.by(1)
    end

    it 'sets the correct value of the query' do
      post("/app/data_sources/#{data_source.id}/queries", params: { query: query_string })
      query = Query.where(data_source_id: data_source.id).last
      expect(query.query).to eq(query_string)
    end

    it 'redirects to the new query' do
      post("/app/data_sources/#{data_source.id}/queries", params: { query: query_string })
      query = Query.where(data_source_id: data_source.id).last
      expect(response).to redirect_to(app_data_source_query_path(data_source, query))
    end
  end
end
