# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventChannel, type: :channel do
  let(:data_source_uuid) { SecureRandom.uuid }
  let(:visitor_uuid) { SecureRandom.uuid }
  let(:session_uuid) { SecureRandom.uuid }
  let(:event) { { type: 'click' } }

  before do
    allow(Rails.logger).to receive(:info).and_call_original
  end

  let(:current_visitor) do
    "#{data_source_uuid}::#{visitor_uuid}::#{session_uuid}"
  end

  describe '#subscribed' do
    it 'connects' do
      stub_connection(current_visitor:)
      subscribe
      expect(Rails.logger).to have_received(:info).with("Visitor connected #{current_visitor}")
    end
  end

  describe '#unsubscribed' do
    before do
      stub_connection(current_visitor:)
      subscribe
    end

    it 'disconnects' do
      subscription.unsubscribe_from_channel
      expect(Rails.logger).to have_received(:info).with("Visitor disconnected #{current_visitor}")
    end
  end

  describe '#event' do
    it 'stores the events' do
      stub_connection(current_visitor:)

      subscribe

      expect { perform :event, event }.to have_enqueued_job(EventSaveJob).with(
        'type' => 'click',
        'action' => 'event'
      )
    end
  end
end
