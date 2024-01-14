# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryService, disable_transactions: true do
  let(:instance) { described_class.new(query:) }

  let(:data_source) { create(:data_source) }
  let(:session_uuid) { SecureRandom.uuid }
  let(:visitor_uuid) { SecureRandom.uuid }

  # TODO: Replace the where data_source_uuid when that part is implemented
  let(:query_string) { "SELECT * FROM clicks WHERE data_source_uuid = '#{data_source.external_uuid}'" }
  let(:query) { create(:query, data_source:, query: query_string) }

  let!(:click_1) { create(:click, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }
  let!(:click_2) { create(:click, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }
  let!(:click_3) { create(:click, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }

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
      expect(instance.execute.rows).to match_array([
        [
          click_1.uuid,
          click_1.data_source_uuid,
          click_1.session_uuid,
          click_1.visitor_uuid,
          click_1.timestamp,
          click_1.coordinates_x,
          click_1.coordinates_y,
          click_1.xpath,
          click_1.inner_text,
          click_1.attribute_id,
          click_1.attribute_class
        ],
        [
          click_2.uuid,
          click_2.data_source_uuid,
          click_2.session_uuid,
          click_2.visitor_uuid,
          click_2.timestamp,
          click_2.coordinates_x,
          click_2.coordinates_y,
          click_2.xpath,
          click_2.inner_text,
          click_2.attribute_id,
          click_2.attribute_class
        ],
        [
          click_3.uuid,
          click_3.data_source_uuid,
          click_3.session_uuid,
          click_3.visitor_uuid,
          click_3.timestamp,
          click_3.coordinates_x,
          click_3.coordinates_y,
          click_3.xpath,
          click_3.inner_text,
          click_3.attribute_id,
          click_3.attribute_class
        ]
      ])
    end

    it 'has no error' do
      expect(instance.execute.error).to eq(false)
    end

    it 'has no error message' do
      expect(instance.execute.error_message).to eq(nil)
    end
  end

  context 'when a database error occurs' do
    let(:query_string) { 'SELECT * FROM clicks with a syntax error' }

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

    it 'has empty rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('Code: 62. DB::Exception: Syntax error')
    end
  end

  context 'when a standard eror occurs' do
    before do
      allow(Click).to receive(:find_by_sql).and_raise(StandardError)
    end

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

    it 'has empty rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has a generic error message' do
      expect(instance.execute.error_message).to include('There was an unkown error, please try again')
    end
  end

  context 'when querying different models' do
    context 'and the model is sessions' do
      let(:query_string) { 'SELECT * FROM sessions' }

      it 'has the correct columns' do
        expect(instance.execute.columns).to eq(%w[
          uuid
          data_source_uuid
          session_uuid
          visitor_uuid
          timestamp
          viewport_x
          viewport_y
          device_x
          device_y
          referrer
          locale
          useragent
          browser
          timezone
          country_code
          utm_source
          utm_medium
          utm_campaign
          utm_content
          utm_term
        ])
      end
    end

    context 'and the model is page_views' do
      let(:query_string) { 'SELECT * FROM page_views' }

      it 'has the correct columns' do
        expect(instance.execute.columns).to eq(%w[
          uuid
          data_source_uuid
          session_uuid
          visitor_uuid
          timestamp
          url
        ])
      end
    end

    context 'and the model is unknown' do
      let(:query_string) { 'SELECT * FROM not_a_real_model' }

      it 'has empty columns' do
        expect(instance.execute.columns).to eq([])
      end

      it 'has an error' do
        expect(instance.execute.error).to eq(true)
      end

      it 'has an error message' do
        expect(instance.execute.error_message).to eq("'not_a_real_model' is not a valid table name")
      end
    end

    context 'and there is no model present' do
      let(:query_string) { 'SELECT *' }

      it 'has empty columns' do
        expect(instance.execute.columns).to eq([])
      end

      it 'has an error' do
        expect(instance.execute.error).to eq(true)
      end

      it 'has an error message' do
        expect(instance.execute.error_message).to eq('No valid table present in query')
      end
    end
  end
end
