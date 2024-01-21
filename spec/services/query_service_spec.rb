# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryService do
  let(:instance) { described_class.new(query:) }

  let(:data_source) { create(:data_source) }
  let(:query) { create(:query, data_source:, query: query_string) }

  context 'when querying the clicks table' do
    let(:query_string) do
      <<-SQL.squish
        SELECT *
        FROM clicks
      SQL
    end

    let!(:click_1) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:click_2) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:click_3) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }

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

  context 'when querying the page views table' do
    let(:query_string) do
      <<-SQL.squish
        SELECT *
        FROM page_views
      SQL
    end

    let!(:page_view_1) { create(:page_view, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:page_view_2) { create(:page_view, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:page_view_3) { create(:page_view, data_source:, data_source_uuid: data_source.external_uuid) }

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

    it 'has the correct rows' do
      expect(instance.execute.rows).to match_array([
        [
          page_view_1.id,
          page_view_1.data_source_uuid,
          page_view_1.session_uuid,
          page_view_1.visitor_uuid,
          page_view_1.timestamp,
          page_view_1.url,
          page_view_1.data_source_id,
          page_view_1.created_at,
          page_view_1.updated_at
        ],
        [
          page_view_2.id,
          page_view_2.data_source_uuid,
          page_view_2.session_uuid,
          page_view_2.visitor_uuid,
          page_view_2.timestamp,
          page_view_2.url,
          page_view_2.data_source_id,
          page_view_2.created_at,
          page_view_2.updated_at
        ],
        [
          page_view_3.id,
          page_view_3.data_source_uuid,
          page_view_3.session_uuid,
          page_view_3.visitor_uuid,
          page_view_3.timestamp,
          page_view_3.url,
          page_view_3.data_source_id,
          page_view_3.created_at,
          page_view_3.updated_at
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

  context 'when querying sessions' do
    let(:query_string) do
      <<-SQL.squish
        SELECT *
        FROM sessions
      SQL
    end

    let!(:session_1) { create(:session, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:session_2) { create(:session, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:session_3) { create(:session, data_source:, data_source_uuid: data_source.external_uuid) }

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

    it 'has the correct rows' do
      expect(instance.execute.rows).to match_array([
        [
          session_1.id,
          session_1.data_source_uuid,
          session_1.session_uuid,
          session_1.visitor_uuid,
          session_1.timestamp,
          session_1.viewport_x,
          session_1.viewport_y,
          session_1.device_x,
          session_1.device_y,
          session_1.referrer,
          session_1.locale,
          session_1.useragent,
          session_1.browser,
          session_1.timezone,
          session_1.country_code,
          session_1.utm_source,
          session_1.utm_medium,
          session_1.utm_campaign,
          session_1.utm_content,
          session_1.utm_term,
          session_1.data_source_id,
          session_1.created_at,
          session_1.updated_at
        ],
        [
          session_2.id,
          session_2.data_source_uuid,
          session_2.session_uuid,
          session_2.visitor_uuid,
          session_2.timestamp,
          session_2.viewport_x,
          session_2.viewport_y,
          session_2.device_x,
          session_2.device_y,
          session_2.referrer,
          session_2.locale,
          session_2.useragent,
          session_2.browser,
          session_2.timezone,
          session_2.country_code,
          session_2.utm_source,
          session_2.utm_medium,
          session_2.utm_campaign,
          session_2.utm_content,
          session_2.utm_term,
          session_2.data_source_id,
          session_2.created_at,
          session_2.updated_at
        ],
        [
          session_3.id,
          session_3.data_source_uuid,
          session_3.session_uuid,
          session_3.visitor_uuid,
          session_3.timestamp,
          session_3.viewport_x,
          session_3.viewport_y,
          session_3.device_x,
          session_3.device_y,
          session_3.referrer,
          session_3.locale,
          session_3.useragent,
          session_3.browser,
          session_3.timezone,
          session_3.country_code,
          session_3.utm_source,
          session_3.utm_medium,
          session_3.utm_campaign,
          session_3.utm_content,
          session_3.utm_term,
          session_3.data_source_id,
          session_3.created_at,
          session_3.updated_at
        ],
      ])
    end

    it 'has no error' do
      expect(instance.execute.error).to eq(false)
    end

    it 'has no error message' do
      expect(instance.execute.error_message).to eq(nil)
    end
  end

  context 'when querying tables that are not allowed' do
    let(:query_string) do
      <<-SQL.squish
        SELECT *
        FROM ar_internal_metadata
      SQL
    end

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq([])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('PG::InsufficientPrivilege')
    end
  end

  context 'when making queries with aggegates' do
    let(:query_string) do
      <<-SQL.squish
        SELECT COUNT(*) count, session_uuid
        FROM clicks
        GROUP BY session_uuid
        ORDER BY count DESC
      SQL
    end

    let(:session_1_uuid) { SecureRandom.uuid }
    let(:session_2_uuid) { SecureRandom.uuid }

    let!(:click_1) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid: session_1_uuid) } # rubocop:disable Layout/LineLength
    let!(:click_2) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid: session_1_uuid) } # rubocop:disable Layout/LineLength
    let!(:click_3) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid: session_2_uuid) } # rubocop:disable Layout/LineLength

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq(%w[count session_uuid])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([
        [2, session_1_uuid],
        [1, session_2_uuid]
      ])
    end

    it 'has no error' do
      expect(instance.execute.error).to eq(false)
    end

    it 'has no error message' do
      expect(instance.execute.error_message).to eq(nil)
    end
  end

  context 'when making queries with joins' do
    let(:query_string) do
      <<-SQL.squish
        SELECT sessions.browser, clicks.coordinates_x
        FROM clicks
        INNER JOIN sessions ON sessions.session_uuid = clicks.session_uuid
      SQL
    end

    let(:session_uuid) { SecureRandom.uuid }

    let!(:session) { create(:session, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, browser: 'Chrome') } # rubocop:disable Layout/LineLength

    let!(:click_1) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, coordinates_x: 100) } # rubocop:disable Layout/LineLength
    let!(:click_2) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, coordinates_x: 200) } # rubocop:disable Layout/LineLength
    let!(:click_3) { create(:click, data_source:, data_source_uuid: data_source.external_uuid, session_uuid:, coordinates_x: 300) } # rubocop:disable Layout/LineLength

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq(%w[browser coordinates_x])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to match_array([
        ['Chrome', 100],
        ['Chrome', 200],
        ['Chrome', 300]
      ])
    end

    it 'has no error' do
      expect(instance.execute.error).to eq(false)
    end

    it 'has no error message' do
      expect(instance.execute.error_message).to eq(nil)
    end
  end

  context 'when the syntax is invalid' do
    let(:query_string) do
      <<-SQL.squish
        SELECT *
        FROM clicks
        WHERE THE SYNTAX IS TOTALLY NOT CORRECT
      SQL
    end

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq([])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('PG::SyntaxError')
    end
  end

  context 'when data from other data sources exists' do
    let(:query_string) do
      <<-SQL.squish
        SELECT data_source_uuid
        FROM clicks
      SQL
    end

    let(:data_source) { create(:data_source) }
    let(:not_our_data_source_1) { create(:data_source) }
    let(:not_our_data_source_2) { create(:data_source) }

    let!(:click_1) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:click_2) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }
    let!(:click_3) { create(:click, data_source:, data_source_uuid: data_source.external_uuid) }

    let!(:click_4) { create(:click, data_source: not_our_data_source_1, data_source_uuid: not_our_data_source_1.external_uuid) } # rubocop:disable Layout/LineLength
    let!(:click_5) { create(:click, data_source: not_our_data_source_2, data_source_uuid: not_our_data_source_2.external_uuid) } # rubocop:disable Layout/LineLength

    it 'returns data with allowed data source' do
      expect(instance.execute.rows.flatten).to eq([
        data_source.external_uuid,
        data_source.external_uuid,
        data_source.external_uuid
      ])
    end

    it 'does not return data for other data sources' do
      expect(instance.execute.rows.flatten).not_to include(not_our_data_source_1.external_uuid)
      expect(instance.execute.rows.flatten).not_to include(not_our_data_source_2.external_uuid)
    end
  end

  context 'when attempting to drop a table' do
    let(:query_string) do
      <<-SQL.squish
        DROP TABLE clicks
      SQL
    end

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq([])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('PG::InsufficientPrivilege')
    end
  end

  context 'when an unexpected error occurs' do
    let(:query_string) do
      <<-SQL.squish
        SELECT d*
        FROM clicks
      SQL
    end

    before do
      allow(instance).to receive(:execute_query).and_raise(StandardError)
    end

    it 'has the correct columns' do
      expect(instance.execute.columns).to eq([])
    end

    it 'has the correct rows' do
      expect(instance.execute.rows).to eq([])
    end

    it 'has an error' do
      expect(instance.execute.error).to eq(true)
    end

    it 'has an error message' do
      expect(instance.execute.error_message).to include('There was an unkown error, please try again')
    end
  end
end
