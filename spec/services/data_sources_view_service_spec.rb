# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourcesViewService do
  let(:data_source) { create(:data_source) }

  let(:instance) { DataSourcesViewService.new(data_source:) }

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

  describe '#replace_table_name' do
    it 'replaces the default table name with the view' do
      expect(instance.replace_table_name('select * from clicks')).to eq("select * from #{instance.view_name(Click)}")
    end
  end

  describe '#view_name' do
    it 'returns the view name for the model' do
      expect(instance.view_name(Click)).to start_with('data_source_')
      expect(instance.view_name(Click)).to end_with('clicks')
    end
  end
end
