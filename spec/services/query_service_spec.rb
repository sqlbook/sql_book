# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryService, disable_transactions: true do
  let(:instance) { described_class.new(query:) }

  let(:data_source) { create(:data_source) }
  let(:query_string) { 'SELECT * FROM clicks' }
  let(:query) { create(:query, data_source:, query: query_string) }

  before do
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
  end

  context 'when a valid query has been given' do
    it 'has the correct columns' do
      expect(instance.execute.columns).to eq(%w[
        uuid
        data_source_uuid
        session_uuid
        visitor_uuid
        timestamp
        coordinates_x
        coordinates_y
        xpath
        inner_text
        attribute_id
        attribute_class
      ])
    end

    it 'has the correct rows' do
      # TODO: Implement once service is scoped to data source
      expect(true).to eq(true)
    end
  end
end
