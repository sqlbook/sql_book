# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryCardBuilder do
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
  end
end
