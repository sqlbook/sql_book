# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventSaveJob, type: :job do
  include ActiveJob::TestHelper

  let(:data_source) { create(:data_source) }

  let(:session_uuid) { SecureRandom.uuid }
  let(:visitor_uuid) { SecureRandom.uuid }

  let(:timestamp) { Time.current.to_i * 1000 }

  let(:args) do
    [
      {
        'type' => 'session',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'locale' => 'en-GB',
        'device_x' => 1920,
        'device_y' => 1080,
        'viewport_x' => 1920,
        'viewport_y' => 1080,
        'referrer' => 'https://google.com',
        'useragent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15', # rubocop:disable Layout/LineLength
        'timezone' => 'Europe/London',
        'utm_campaign' => nil,
        'utm_content' => nil,
        'utm_medium' => nil,
        'utm_source' => nil,
        'utm_term' => nil
      },
      {
        'type' => 'page_view',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'url' => 'http://localhost:3000/'
      },
      {
        'type' => 'page_view',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'url' => 'http://localhost:3000/about'
      },
      {
        'type' => 'click',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'coordinates_x' => 50,
        'coordinates_y' => 150,
        'selector' => 'body > main > div.workspaces.container.lg > div:nth-child(1) > div.details > p',
        'inner_text' => nil,
        'attributes_id' => nil,
        'attributes_class' => nil
      },
      {
        'type' => 'click',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'coordinates_x' => 25,
        'coordinates_y' => 110,
        'selector' => 'body > main > div.workspaces.container.lg > div:nth-child(1) > div.details > p',
        'inner_text' => nil,
        'attributes_id' => nil,
        'attributes_class' => 'icon'
      },
      {
        'type' => 'click',
        'data_source_uuid' => data_source.external_uuid,
        'session_uuid' => session_uuid,
        'visitor_uuid' => visitor_uuid,
        'timestamp' => timestamp,
        'coordinates_x' => 450,
        'coordinates_y' => 250,
        'selector' => 'body > main > div.workspaces.container.lg > div:nth-child(1) > div.details > p',
        'inner_text' => 'Query Library',
        'attributes_id' => nil,
        'attributes_class' => nil
      }
    ]
  end

  subject { described_class.perform_now(*args) }

  it 'stores all of the events' do
    subject
    expect(data_source.sessions.count).to eq(1)
    expect(data_source.page_views.count).to eq(2)
    expect(data_source.clicks.count).to eq(3)
  end
end
