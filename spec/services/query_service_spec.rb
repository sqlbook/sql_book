# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryService do
  let(:instance) { described_class.new(query:) }

  let(:data_source) { create(:data_source) }
  let(:session_uuid) { SecureRandom.uuid }
  let(:visitor_uuid) { SecureRandom.uuid }

  let(:query_string) { 'SELECT * FROM clicks' }
  let(:query) { create(:query, data_source:, query: query_string) }

  let!(:click_1) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }
  let!(:click_2) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }
  let!(:click_3) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, visitor_uuid:) }

  context 'when a valid query has been given' do
    it 'has the correct columns' do
      expect(instance.execute.columns).to eq(%w[
        id
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
        data_source_id
        created_at
        updated_at
      ])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to match_array([
        [
          click_1.id,
          click_1.data_source_uuid,
          click_1.session_uuid,
          click_1.visitor_uuid,
          click_1.timestamp,
          click_1.coordinates_x,
          click_1.coordinates_y,
          click_1.xpath,
          click_1.inner_text,
          click_1.attribute_id,
          click_1.attribute_class,
          click_1.data_source_id,
          click_1.created_at,
          click_1.updated_at
        ],
        [
          click_2.id,
          click_2.data_source_uuid,
          click_2.session_uuid,
          click_2.visitor_uuid,
          click_2.timestamp,
          click_2.coordinates_x,
          click_2.coordinates_y,
          click_2.xpath,
          click_2.inner_text,
          click_2.attribute_id,
          click_2.attribute_class,
          click_2.data_source_id,
          click_2.created_at,
          click_2.updated_at
        ],
        [
          click_3.id,
          click_3.data_source_uuid,
          click_3.session_uuid,
          click_3.visitor_uuid,
          click_3.timestamp,
          click_3.coordinates_x,
          click_3.coordinates_y,
          click_3.xpath,
          click_3.inner_text,
          click_3.attribute_id,
          click_3.attribute_class,
          click_3.data_source_id,
          click_3.created_at,
          click_3.updated_at
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

    it 'has empty columns' do
      expect(instance.execute.columns).to eq([])
    end

    it 'has empty rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('PG::SyntaxError: ERROR:  syntax error')
    end
  end

  context 'when making queries that differ from the model' do
    let(:query_string) do
      <<-SQL.squish
        SELECT COUNT(*) count, session_uuid
        FROM clicks
        GROUP BY session_uuid
        ORDER BY count desc;
      SQL
    end

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq(%w[count session_uuid])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([
        [3, session_uuid]
      ])
    end

    it 'has no error' do
      expect(instance.execute.error).to eq(false)
    end

    it 'has no error message' do
      expect(instance.execute.error_message).to eq(nil)
    end
  end

  context 'when querying different models' do
    context 'and the model is sessions' do
      let(:query_string) { 'SELECT * FROM sessions' }

      it 'has the correct columns' do
        expect(instance.execute.columns).to eq(%w[
          id
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
          data_source_id
          created_at
          updated_at
        ])
      end
    end

    context 'and the model is page_views' do
      let(:query_string) { 'SELECT * FROM page_views' }

      it 'has the correct columns' do
        expect(instance.execute.columns).to eq(%w[
          id
          data_source_uuid
          session_uuid
          visitor_uuid
          timestamp
          url
          data_source_id
          created_at
          updated_at
        ])
      end
    end
  end
end
