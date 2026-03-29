# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::NameGenerator do
  let(:workspace) { create(:workspace_with_owner) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }

  describe '.generate' do
    it 'prefers a cleaned user question when present' do
      name = described_class.generate(
        question: 'Who are the longest standing users in my staging db?',
        sql: 'SELECT id, created_at FROM public.users ORDER BY created_at ASC',
        data_source:
      )

      expect(name).to eq('longest standing users')
    end

    it 'falls back to a generic count name from sql' do
      name = described_class.generate(
        question: '',
        sql: 'SELECT COUNT(*) AS user_count FROM public.users',
        data_source:
      )

      expect(name).to eq('User count')
    end

    it 'falls back to a generic table query name from sql' do
      name = described_class.generate(
        question: '',
        sql: 'SELECT * FROM public.users',
        data_source:
      )

      expect(name).to eq('Users query')
    end
  end

  describe '.descriptive_name_from_sql' do
    it 'returns nil when there is no discernible table' do
      expect(described_class.descriptive_name_from_sql(sql: 'SELECT now()')).to be_nil
    end
  end
end
