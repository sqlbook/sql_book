# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourceViewService do
  let(:data_source) { create(:data_source) }

  let(:instance) { DataSourceViewService.new(data_source:) }

  describe '#create!' do
    after { instance.destroy! }

    it 'creates the views' do
      expect { instance.create! }.to change { instance.exists? }.from(false).to(true)
    end
  end

  describe '#destroy!' do
    before { instance.create! }

    it 'destroys the views' do
      expect { instance.destroy! }.to change { instance.exists? }.from(true).to(false)
    end
  end

  describe '#exists?' do
    context 'when the views do not exist' do
      it 'returns false' do
        expect(instance.exists?).to eq(false)
      end
    end

    context 'when the views exist' do
      before { instance.create! }
      after { instance.destroy! }

      it 'returns true' do
        expect(instance.exists?).to eq(true)
      end
    end
  end
end
