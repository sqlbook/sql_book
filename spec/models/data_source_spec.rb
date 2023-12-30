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
end
