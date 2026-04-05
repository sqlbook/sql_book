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

  describe 'POST /app/workspaces/:workspace_id/query-editor/generate-name' do
    it 'generates a name without persisting a query' do
      allow(Queries::GeneratedNameService).to receive(:generate).and_return('User count')
      allow(Queries::SchemaContextBuilder).to receive(:call).with(data_source:).and_return(['public.users: id'])

      expect do
        post app_workspace_query_editor_generate_name_path(workspace),
             params: {
               data_source_id: data_source.id,
               sql:
             },
             as: :json
      end.not_to change(Query, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'generated_name')).to eq('User count')
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
               group_names: ['Key Numbers', 'User Stats'],
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
      end.to change(Query, :count).by(1)
        .and change(QueryVisualization, :count).by(2)
        .and change(QueryGroup, :count).by(2)
        .and change(QueryGroupMembership, :count).by(2)

      query = Query.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('created')
      expect(response.parsed_body.dig('data', 'query', 'visualization_types')).to eq(%w[line pie])
      expect(response.parsed_body.dig('data', 'query', 'group_names')).to eq(['Key Numbers', 'User Stats'])
      expect(response.parsed_body.dig('data', 'available_query_groups')).to eq(['Key Numbers', 'User Stats'])
      saved_visualizations = response.parsed_body.dig('data', 'query', 'visualizations')
      expect(saved_visualizations.map { |visualization| visualization['chart_type'] }).to eq(%w[line pie])
      expect(query.reload.saved).to eq(true)
      expect(query.group_names).to eq(['Key Numbers', 'User Stats'])
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
      traffic_group = create(:query_group, workspace:, name: 'Traffic')
      create(:query_group_membership, query:, query_group: traffic_group)
      create(:query_visualization, query:, chart_type: 'line')

      expect do
        post app_workspace_query_editor_save_path(workspace),
             params: {
               query_id: query.id,
               data_source_id: data_source.id,
               name: 'Updated user count',
               sql:,
               group_names: ['Key Numbers', 'Traffic'],
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
        .and change(QueryGroup, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'save_outcome')).to eq('updated')
      expect(query.group_names).to eq(['Key Numbers', 'Traffic'])
      expect(query.visualizations.order(:chart_type).pluck(:chart_type)).to eq(%w[bar line])
    end

    it 'removes orphaned groups when the last query leaves them' do
      query = create(
        :query,
        data_source:,
        author: owner,
        last_updated_by: owner,
        saved: true,
        name: 'User count',
        query: sql
      )
      audience_group = create(:query_group, workspace:, name: 'Audience')
      create(:query_group_membership, query:, query_group: audience_group)

      expect do
        post app_workspace_query_editor_save_path(workspace),
             params: {
               query_id: query.id,
               data_source_id: data_source.id,
               name: 'User count',
               sql:,
               group_names: []
             },
             as: :json
      end.to change(QueryGroupMembership, :count).by(-1)
        .and change(QueryGroup, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(query.reload.group_names).to eq([])
      expect(QueryGroup.exists?(audience_group.id)).to eq(false)
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
