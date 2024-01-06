# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventChannel, type: :channel do
  let(:data_source_uuid) { SecureRandom.uuid }
  let(:visitor_uuid) { SecureRandom.uuid }
  let(:session_uuid) { SecureRandom.uuid }

  let(:current_visitor) do
    "#{data_source_uuid}::#{visitor_uuid}::#{session_uuid}"
  end

  describe '#event' do
    it 'stores the events' do
      stub_connection(current_visitor:)

      subscribe

      expect(true).to eq(true) # TODO
    end
  end
end
