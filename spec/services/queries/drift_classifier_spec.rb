# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::DriftClassifier do
  describe '#call' do
    it 'treats a limit-only change as a minor refinement' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:)
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Top 5 longest-standing users by earliest signup date',
        query: 'SELECT id, created_at FROM public.users ORDER BY created_at ASC NULLS LAST LIMIT 5;'
      )

      result = described_class.new(
        saved_query:,
        draft_sql: 'SELECT id, created_at FROM public.users ORDER BY created_at ASC NULLS LAST LIMIT 10;',
        generated_name: '10 longest standing users'
      ).call

      expect(result.classification).to eq('minor_refinement')
    end

    it 'treats an opposite ordering change as material drift' do
      workspace = create(:workspace_with_owner)
      data_source = create(:data_source, :postgres, workspace:)
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'Top 10 longest-standing users by earliest signup date',
        query: 'SELECT id, created_at FROM public.users ORDER BY created_at ASC NULLS LAST LIMIT 10;'
      )

      result = described_class.new(
        saved_query:,
        draft_sql: 'SELECT id, created_at FROM public.users ORDER BY created_at DESC NULLS LAST LIMIT 10;',
        generated_name: '10 newest users by created at'
      ).call

      expect(result.classification).to eq('material_drift')
    end
  end
end
