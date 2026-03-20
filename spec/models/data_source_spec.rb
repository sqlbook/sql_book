# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSource, type: :model do
  describe '.format_as_url_origin' do
    context 'when the url is valid' do
      let(:valid_urls) do
        [
          {
            from: 'https://sqlbook.com',
            to: 'https://sqlbook.com'
          },
          {
            from: 'https://test.sqlbook.com',
            to: 'https://test.sqlbook.com'
          },
          {
            from: 'https://sqlbook.com/test',
            to: 'https://sqlbook.com'
          }
        ]
      end

      it 'returns the valid origin' do
        valid_urls.each do |valid_url|
          expect(described_class.format_as_url_origin(valid_url[:from])).to eq(valid_url[:to])
        end
      end
    end

    context 'when the url is invalid' do
      let(:invalid_urls) do
        [
          'https://sqlbook',
          'asdasdsad',
          'https://sqlbook🐈'
        ]
      end

      it 'returns nil' do
        invalid_urls.each do |invalid_url|
          expect(described_class.format_as_url_origin(invalid_url)).to eq(nil)
        end
      end
    end
  end

  describe 'capture source uniqueness' do
    it 'allows the same url in different workspaces' do
      url = 'https://sqlbook.com'
      create(:data_source, url:, workspace: create(:workspace))
      duplicate = build(:data_source, url:, workspace: create(:workspace))

      expect(duplicate).to be_valid
    end
  end

  describe '#verified?' do
    context 'when the data source is not verified' do
      let(:instance) { create(:data_source) }

      it 'returns false' do
        expect(instance.verified?).to eq(false)
      end
    end

    context 'when the data source is verified' do
      let(:instance) { create(:data_source, verified_at: Time.current) }

      it 'returns true' do
        expect(instance.verified?).to eq(true)
      end
    end
  end

  describe 'postgres connectors' do
    let(:workspace) { create(:workspace) }

    it 'is valid with postgres connection details' do
      data_source = build(:data_source, :postgres, workspace:)

      expect(data_source).to be_valid
      expect(data_source.connection_password).to eq('super-secret')
      expect(data_source.selected_tables).to eq(%w[public.orders public.customers])
    end

    it 'requires a password for postgres sources' do
      data_source = build(:data_source, :postgres, workspace:)
      data_source.connection_password = nil

      expect(data_source).not_to be_valid
      expect(data_source.errors[:connection_password]).to include("can't be blank")
    end

    it 'enforces the selected tables limit' do
      data_source = build(:data_source, :postgres, workspace:)
      data_source.selected_tables = Array.new(DataSource::MAX_SELECTED_TABLES + 1) { |index| "public.table_#{index}" }

      expect(data_source).not_to be_valid
      expect(data_source.errors[:selected_tables]).to include(I18n.t('models.data_source.selected_tables_limit',
                                                                     count: DataSource::MAX_SELECTED_TABLES))
    end
  end
end
