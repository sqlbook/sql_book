# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryRefinementResolver do
  describe '#resolve' do
    it 'does not infer a target saved query from stale recent_saved_query_state alone' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Users',
        query: 'SELECT id, first_name, last_name, email, terms_accepted_at FROM public.users LIMIT 10;'
      )

      context_snapshot = Chat::ContextSnapshot.new(
        query_references: [
          {
            'id' => 1,
            'sql' => 'SELECT id, first_name, last_name, email FROM public.users LIMIT 10;',
            'data_source_id' => data_source.id,
            'data_source_name' => data_source.display_name,
            'saved_query_id' => nil,
            'saved_query_name' => nil
          }
        ],
        recent_query_state: {
          'saved_query_id' => saved_query.id,
          'saved_query_name' => saved_query.name
        }
      )

      result = described_class.new(workspace:, context_snapshot:).resolve

      expect(result.target_query).to be_nil
      expect(result.classification).to be_nil
    end

    it 'resolves a target saved query when the draft is explicitly linked via refined_saved_query_id' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:, name: 'Staging App DB')
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Users',
        query: 'SELECT id, first_name, last_name, email, terms_accepted_at FROM public.users LIMIT 10;'
      )

      context_snapshot = Chat::ContextSnapshot.new(
        query_references: [
          {
            'id' => 1,
            'sql' => 'SELECT id, first_name, last_name, email FROM public.users LIMIT 10;',
            'data_source_id' => data_source.id,
            'data_source_name' => data_source.display_name,
            'saved_query_id' => nil,
            'saved_query_name' => nil,
            'refined_saved_query_id' => saved_query.id
          }
        ],
        recent_query_state: {}
      )

      result = described_class.new(workspace:, context_snapshot:).resolve

      expect(result.target_query).to eq(saved_query)
      expect(result.classification).to be_present
    end
  end
end
