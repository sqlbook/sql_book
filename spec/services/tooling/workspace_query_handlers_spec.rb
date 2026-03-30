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

    it 'returns a suggested_name when updated sql changes the saved query purpose and no name was supplied' do
      actor = create(:user)
      workspace = create(:workspace_with_owner, owner: actor)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      query = create(
        :query,
        data_source:,
        saved: true,
        name: '5 longest standing users',
        query: [
          'SELECT id, first_name, last_name, email, created_at',
          'FROM public.users',
          'ORDER BY created_at ASC NULLS LAST',
          'LIMIT 5;'
        ].join(' '),
        author: actor,
        last_updated_by: actor
      )

      updated_sql = [
        'SELECT id, first_name, last_name, email, created_at',
        'FROM public.users',
        'ORDER BY created_at ASC NULLS LAST',
        'LIMIT 10;'
      ].join(' ')
      query_result = ActiveRecord::Result.new(
        %w[id first_name last_name email created_at],
        [[8, 'Bob', 'Smith', 'hello@sitelabs.ai', '2026-02-25 16:55:12.700164']]
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)
      allow(Queries::NameReviewService)
        .to receive(:review)
        .and_return(
          Queries::NameReviewResponseParser::Result.new(
            status: 'stale',
            suggested_name: '10 longest standing users',
            reason: 'LIMIT changed from 5 to 10'
          )
        )

      result = described_class.new(workspace:, actor:).update(
        arguments: { 'query_id' => query.id, 'sql' => updated_sql }
      )

      expect(result.status).to eq('executed')
      expect(result.data['suggested_name']).to eq('10 longest standing users')
      expect(result.data['current_name']).to eq('5 longest standing users')
      expect(result.data['name_review']).to include(
        'status' => 'stale',
        'suggested_name' => '10 longest standing users'
      )
      expect(result.data['next_actions']).to include(
        include('action_type' => 'query.rename')
      )
      expect(result.data['follow_up']).to include(
        'kind' => 'query_rename_suggestion',
        'target_id' => query.id
      )
    end

    it 'does not return a suggested_name when the current query name still broadly fits' do
      actor = create(:user)
      workspace = create(:workspace_with_owner, owner: actor)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Longest standing users',
        query: [
          'SELECT id, first_name, last_name, email, created_at',
          'FROM public.users',
          'ORDER BY created_at ASC NULLS LAST',
          'LIMIT 5;'
        ].join(' '),
        author: actor,
        last_updated_by: actor
      )

      updated_sql = [
        'SELECT id, first_name, last_name, email, created_at',
        'FROM public.users',
        'ORDER BY created_at ASC NULLS LAST',
        'LIMIT 10;'
      ].join(' ')
      query_result = ActiveRecord::Result.new(
        %w[id first_name last_name email created_at],
        [[8, 'Bob', 'Smith', 'hello@sitelabs.ai', '2026-02-25 16:55:12.700164']]
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:execute_readonly)
        .and_return(query_result)
      allow(Queries::NameReviewService)
        .to receive(:review)
        .and_return(
          Queries::NameReviewResponseParser::Result.new(
            status: 'aligned',
            suggested_name: nil,
            reason: 'Current title is still accurate'
          )
        )

      result = described_class.new(workspace:, actor:).update(
        arguments: { 'query_id' => query.id, 'sql' => updated_sql }
      )

      expect(result.status).to eq('executed')
      expect(result.data).not_to have_key('suggested_name')
      expect(result.data).not_to have_key('current_name')
      expect(result.data['name_review']).to include('status' => 'aligned')
      expect(result.data).not_to have_key('follow_up')
      expect(result.data).not_to have_key('next_actions')
    end
  end
end
