# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources::QueryVisualizations', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:data_source) { create(:data_source, workspace:) }
  let(:query) { create(:query, data_source:, author: owner, last_updated_by: owner, saved: true) }

  before do
    sign_in(owner)
    stub_query_result
  end

  it 'returns the requested visualization type' do
    create(:query_visualization, query:, chart_type: 'bar')

    get app_workspace_data_source_query_visualization_path(workspace, data_source, query, 'bar')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'visualization', 'chart_type')).to eq('bar')
  end

  it 'updates one visualization type without affecting other saved types' do
    create(:query_visualization, query:, chart_type: 'line')
    create(:query_visualization, query:, chart_type: 'pie')

    patch app_workspace_data_source_query_visualization_path(workspace, data_source, query, 'line'),
          params: {
            data_config: { dimension_key: 'month', value_key: 'revenue' },
            other_config: { title: 'Revenue by month' }
          },
          as: :json

    expect(response).to have_http_status(:ok)
    line_visualization = query.reload.visualizations.find_by(chart_type: 'line')

    expect(line_visualization&.other_config&.fetch('title')).to eq('Revenue by month')
    expect(query.visualizations.find_by(chart_type: 'pie')).to be_present
  end

  it 'deletes only the targeted visualization type' do
    create(:query_visualization, query:, chart_type: 'line')
    create(:query_visualization, query:, chart_type: 'pie')

    expect do
      delete app_workspace_data_source_query_visualization_path(workspace, data_source, query, 'line')
    end.to change { query.reload.visualizations.count }.from(2).to(1)

    expect(response).to have_http_status(:ok)
    expect(query.visualizations.find_by(chart_type: 'line')).to be_nil
    expect(query.visualizations.find_by(chart_type: 'pie')).to be_present
  end

  private

  def stub_query_result
    allow_any_instance_of(QueryService).to receive(:execute) do |service|
      service.data = ActiveRecord::Result.new(%w[month revenue], [['Jan', 120]])
      service.error = false
      service.error_message = nil
      service
    end
  end
end
