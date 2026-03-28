# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tooling::WorkspaceQueryHandlers do
  describe '#update' do
    it 'returns refreshed query-run data when sql is updated' do
      actor = create(:user)
      workspace = create(:workspace_with_owner, owner: actor)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User names and email addresses',
        query: 'SELECT id, first_name, last_name, email, terms_accepted_at FROM public.users LIMIT 10;',
        author: actor,
        last_updated_by: actor
      )

      updated_sql = 'SELECT id, first_name, last_name, email FROM public.users LIMIT 10;'
      query_result = ActiveRecord::Result.new(
        %w[id first_name last_name email],
        [[8, 'Bob', 'Smith', 'hello@sitelabs.ai']]
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)

      result = described_class.new(workspace:, actor:).update(
        arguments: { 'query_id' => query.id, 'sql' => updated_sql }
      )

      expect(result.status).to eq('executed')
      expect(result.data['update_outcome']).to eq('updated')
      expect(result.data['sql']).to eq(updated_sql)
      expect(result.data['columns']).to eq(%w[id first_name last_name email])
      expect(result.data['rows']).to eq([[8, 'Bob', 'Smith', 'hello@sitelabs.ai']])
      expect(result.data['row_count']).to eq(1)
      expect(result.data.dig('query', 'sql')).to eq(updated_sql)
    end
  end
end
