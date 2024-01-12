# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Query, type: :model do
  describe '#query_result' do
    let(:instance) { create(:query) }
    let(:query_service) { instance_double('QueryService') }

    subject { instance.query_result }

    before do
      allow(QueryService).to receive(:new).and_return(query_service)
      allow(query_service).to receive(:execute).and_return(query_service)
    end

    it 'returns an instance of the QueryService' do
      expect(subject).to eq(query_service)
    end

    it 'executes the query' do
      subject
      expect(query_service).to have_received(:execute)
    end
  end
end
