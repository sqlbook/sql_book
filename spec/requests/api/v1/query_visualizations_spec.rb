# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 query visualizations', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:data_source) { create(:data_source, workspace:) }
  let(:query) { create(:query, data_source:, author: owner, last_updated_by: owner, saved: true) }

  before { sign_in(owner) }

  it 'creates or updates a query visualization' do
    patch "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}/visualization",
          params: {
            chart_type: 'line',
            data_config: { dimension_key: 'month', value_key: 'revenue' },
            other_config: { title: 'Revenue by month' }
          },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('executed')
    expect(response.parsed_body.dig('data', 'visualization', 'chart_type')).to eq('line')
    expect(query.reload.visualization.other_config['title']).to eq('Revenue by month')
  end

  it 'returns the structured visualization for a query' do
    create(:query_visualization, query:, chart_type: 'bar')

    get "/api/v1/workspaces/#{workspace.id}/queries/#{query.id}/visualization"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'visualization', 'chart_type')).to eq('bar')
  end
end
