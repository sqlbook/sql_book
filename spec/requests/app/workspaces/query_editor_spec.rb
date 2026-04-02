# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::QueryEditor', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:data_source) { create(:data_source, :postgres, workspace:) }
  let(:sql) { 'SELECT COUNT(*) AS user_count FROM public.users;' }

  before do
    sign_in(owner)
    stub_successful_query_result(columns: ['user_count'], rows: [[3]])
  end

  describe 'POST /app/workspaces/:workspace_id/query-editor/run' do
    it 'runs an unsaved draft without persisting a query and returns a first-pass name' do
      allow(Queries::GeneratedNameService).to receive(:generate).and_return('User count')
      allow(Queries::SchemaContextBuilder).to receive(:call).with(data_source:).and_return(['public.users: id'])

      expect do
        post app_workspace_query_editor_run_path(workspace),
             params: {
               data_source_id: data_source.id,
               sql:,
               request_generated_name: true
             },
             as: :json
      end.not_to change(Query, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'generated_name')).to eq('User count')
      expect(response.parsed_body.dig('data', 'result', 'rows')).to eq([[3]])
      expect(response.parsed_body.dig('data', 'run_token')).to be_present
    end
  end

  describe 'POST /app/workspaces/:workspace_id/query-editor/save' do
    it 'creates a saved query and persists multiple visualization types in one save' do
      expect do
        post app_workspace_query_editor_save_path(workspace),
             params: {
               data_source_id: data_source.id,
               name: 'User count',
               sql:,
               run_token: run_token_for(data_source:, sql:),
               visualizations: [
                 {
                   chart_type: 'line',
                   data_config: { dimension_key: 'created_at', value_key: 'user_count' },
                   other_config: { title: 'Users over time' }
                 },
                 {
                   chart_type: 'pie',
                   data_config: { dimension_key: 'plan', value_key: 'user_count' },
                   other_config: { title: 'Users by plan' }
                 }
               ]
             },
             as: :json
      end.to change(Query, :count).by(1).and change(QueryVisualization, :count).by(2)

      query = Query.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('created')
      expect(query.reload.saved).to eq(true)
      expect(query.visualizations.order(:chart_type).pluck(:chart_type)).to eq(%w[line pie])
    end

    it 'allows visualization and settings-only saves without requiring a rerun' do
      query = create(
        :query,
        data_source:,
        author: owner,
        last_updated_by: owner,
        saved: true,
        name: 'User count',
        query: sql
      )
      create(:query_visualization, query:, chart_type: 'line')

      expect do
        post app_workspace_query_editor_save_path(workspace),
             params: {
               query_id: query.id,
               data_source_id: data_source.id,
               name: 'Updated user count',
               sql:,
               visualizations: [
                 {
                   chart_type: 'line',
                   data_config: { dimension_key: 'month', value_key: 'user_count' }
                 },
                 {
                   chart_type: 'bar',
                   data_config: { dimension_key: 'month', value_key: 'user_count' }
                 }
               ]
             },
             as: :json
      end.to change { query.reload.name }.from('User count').to('Updated user count')
        .and change { query.visualizations.count }.from(1).to(2)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('updated')
      expect(query.visualizations.order(:chart_type).pluck(:chart_type)).to eq(%w[bar line])
    end

    it 'rejects saving SQL changes for a saved query until the updated SQL has run successfully' do
      query = create(
        :query,
        data_source:,
        author: owner,
        last_updated_by: owner,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.sessions;'
      )

      post app_workspace_query_editor_save_path(workspace),
           params: {
             query_id: query.id,
             data_source_id: data_source.id,
             name: 'User count',
             sql:
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('query.run_required')
      expect(query.reload.query).to eq('SELECT COUNT(*) AS user_count FROM public.sessions;')
    end

    it 'returns the existing saved query when the same SQL is already in the library' do
      existing_query = create(
        :query,
        data_source:,
        author: owner,
        last_updated_by: owner,
        saved: true,
        name: 'User count',
        query: sql
      )

      post app_workspace_query_editor_save_path(workspace),
           params: {
             data_source_id: data_source.id,
             name: 'Another name',
             sql:,
             run_token: run_token_for(data_source:, sql:)
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('already_saved')
      expect(response.parsed_body.dig('data', 'query', 'id')).to eq(existing_query.id)
    end
  end

  private

  def run_token_for(data_source:, sql:)
    QueryEditor::RunToken.issue(data_source_id: data_source.id, sql:)
  end

  def stub_successful_query_result(columns:, rows:)
    allow_any_instance_of(DataSources::Connectors::PostgresConnector)
      .to receive(:execute_readonly)
      .and_return(ActiveRecord::Result.new(columns, rows))
  end
end
