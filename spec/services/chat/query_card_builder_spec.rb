# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryCardBuilder do
  describe '#summary_message' do
    it 'uses the standard intro for a fresh query run' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')

      builder = described_class.new(
        workspace:,
        execution_data: {
          'sql' => 'SELECT COUNT(*) AS user_count FROM public.users;',
          'question' => 'How many users do I have?',
          'row_count' => 1,
          'columns' => ['user_count'],
          'rows' => [[3]],
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name }
        },
        intent_payload: {}
      )

      expect(builder.summary_message).to eq('Here’s what I found from Staging App DB (1 row(s)):')
    end

    it 'uses the lighter updated intro for refinement runs' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')

      builder = described_class.new(
        workspace:,
        execution_data: {
          'sql' => 'SELECT first_name, last_name, email, created_at FROM public.users;',
          'question' => 'List users with fewer columns',
          'row_count' => 3,
          'columns' => %w[first_name last_name email created_at],
          'rows' => [['Bob', 'Smith', 'hello@sitelabs.ai', '2026-02-25 16:55:12.700164']],
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name }
        },
        intent_payload: {
          'base_sql' => 'SELECT * FROM public.users;'
        }
      )

      expect(builder.summary_message).to eq('Updated results (3 row(s)):')
    end
  end

  describe '#call' do
    it 'includes schema metadata for the query card when the datasource exposes tables' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return(
          [
            {
              schema: 'public',
              tables: [
                {
                  name: 'users',
                  qualified_name: 'public.users',
                  columns: [
                    { name: 'first_name', data_type: 'character varying', default: nil }
                  ]
                }
              ]
            }
          ]
        )

      payload = described_class.new(
        workspace:,
        execution_data: {
          'sql' => 'SELECT COUNT(*) AS user_count FROM public.users;',
          'question' => 'How many users do I have?',
          'row_count' => 1,
          'columns' => ['user_count'],
          'rows' => [[3]],
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name }
        },
        intent_payload: {}
      ).call

      expect(payload['schema_options']).to eq([['public.users', 'public_users']])
      expect(payload['schema_tables']).to include(
        hash_including(
          'qualified_name' => 'public.users',
          'schema_key' => 'public_users'
        )
      )
    end

    it 'marks query.update cards as saved when execution data includes a saved query payload' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User names and email addresses',
        query: 'SELECT id, first_name, last_name, email FROM public.users LIMIT 10;'
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return([])

      payload = described_class.new(
        workspace:,
        execution_data: {
          'question' => query.name,
          'sql' => query.query,
          'row_count' => 1,
          'columns' => %w[id first_name last_name email],
          'rows' => [[1, 'Bob', 'Smith', 'hello@sitelabs.ai']],
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name },
          'query' => {
            'id' => query.id,
            'name' => query.name,
            'sql' => query.query,
            'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name }
          }
        },
        intent_payload: { 'query_id' => query.id }
      ).call

      expect(payload['state']).to eq('saved')
      expect(payload.dig('saved_query', 'id')).to eq(query.id)
      expect(payload.dig('saved_query', 'name')).to eq(query.name)
    end

    it 'treats materially different opposite-order runs as fresh cards even when a base saved query id is present' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      base_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Top 10 longest-standing users by earliest signup date',
        query: 'SELECT id, first_name, created_at FROM public.users ORDER BY created_at ASC NULLS LAST LIMIT 10;'
      )

      allow_any_instance_of(DataSources::Connectors::PostgresConnector)
        .to receive(:list_tables)
        .and_return([])

      payload = described_class.new(
        workspace:,
        execution_data: {
          'question' => 'What about the 10 newest users?',
          'sql' => 'SELECT id, first_name, created_at FROM public.users ORDER BY created_at DESC NULLS LAST LIMIT 10;',
          'row_count' => 10,
          'columns' => %w[id first_name created_at],
          'rows' => [[39, 'Mila', '2026-03-18 19:00:00']],
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name }
        },
        intent_payload: { 'base_saved_query_id' => base_query.id }
      ).call

      expect(payload['state']).to eq('unsaved')
      expect(payload['base_saved_query']).to be_nil
    end
  end
end
