# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::DataSourcesHelper', type: :helper do
  describe '#tracking_code' do
    let(:data_source) { create(:data_source) }

    it 'adds the exernal uuid to the tracking code' do
      expect(helper.tracking_code(data_source:)).to include(data_source.external_uuid)
    end
  end

  describe '#verifying?' do
    before do
      allow(helper).to receive(:params).and_return(params)
    end

    context 'when the verifying param is present' do
      let(:params) { { 'verifying' => 'true' } }

      it 'returns true' do
        expect(helper.verifying?).to eq(true)
      end
    end

    context 'when the verifying param not is present' do
      let(:params) { {} }

      it 'returns false' do
        expect(helper.verifying?).to eq(false)
      end
    end
  end

  describe '#verification_failed?' do
    before do
      allow(helper).to receive(:params).and_return(params)
    end

    context 'when no verification has happened' do
      let(:params) { {} }

      it 'returns false' do
        expect(helper.verification_failed?).to eq(false)
      end
    end

    context 'when the count is below the limit' do
      let(:params) { { verification_attempt: '1' } }

      it 'returns false' do
        expect(helper.verification_failed?).to eq(false)
      end
    end

    context 'when the count is above the limit' do
      let(:params) { { verification_attempt: '5' } }

      it 'returns true' do
        expect(helper.verification_failed?).to eq(true)
      end
    end
  end
end
