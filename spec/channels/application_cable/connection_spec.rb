# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  describe 'when connecting from app realtime path' do
    let(:user) { create(:user) }

    it 'rejects unauthenticated connections' do
      expect { connect '/cable' }.to have_rejected_connection
    end

    it 'connects authenticated users' do
      connection = connect('/cable', session: { current_user_id: user.id })

      expect(connection.current_user).to eq(user)
    end
  end

  describe 'when no params are provided' do
    it 'rejects the connection' do
      expect { connect '/events/in' }.to have_rejected_connection
    end
  end

  describe 'when only some of the params are provided' do
    let(:params) { "?data_source_uuid=#{SecureRandom.uuid}" }

    it 'rejects the connection' do
      expect { connect "/events/in#{params}" }.to have_rejected_connection
    end
  end

  describe 'when all of the params exist but the data source does not' do
    let(:data_source_uuid) { SecureRandom.uuid }
    let(:visitor_uuid) { SecureRandom.uuid }
    let(:session_uuid) { SecureRandom.uuid }

    let(:params) do
      "?data_source_uuid=#{data_source_uuid}&visitor_uuid=#{visitor_uuid}&session_uuid=#{session_uuid}"
    end

    it 'rejects the connection' do
      expect { connect "/events/in#{params}" }.to have_rejected_connection
    end
  end

  describe 'when all of the params exist, so does the data source, but the origin does not match' do
    let(:data_source) { create(:data_source, url: 'https://not-my-domain.com') }
    let(:visitor_uuid) { SecureRandom.uuid }
    let(:session_uuid) { SecureRandom.uuid }

    let(:params) do
      "?data_source_uuid=#{data_source.external_uuid}&visitor_uuid=#{visitor_uuid}&session_uuid=#{session_uuid}"
    end

    it 'rejects the connection' do
      expect { connect "/events/in#{params}", headers: { origin: 'not_gonna_match' } }.to have_rejected_connection
    end
  end

  describe 'when all the params exist, so does the data source, and the origin is correct' do
    let(:origin) { 'https://my-domain.com' }
    let(:data_source) { create(:data_source, url: origin) }
    let(:visitor_uuid) { SecureRandom.uuid }
    let(:session_uuid) { SecureRandom.uuid }

    let(:params) do
      "?data_source_uuid=#{data_source.external_uuid}&visitor_uuid=#{visitor_uuid}&session_uuid=#{session_uuid}"
    end

    it 'successfully connects' do
      expect(connect("/events/in#{params}", headers: { origin: })).not_to be nil
    end
  end
end
