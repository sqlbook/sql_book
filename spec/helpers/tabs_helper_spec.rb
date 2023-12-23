# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TabsHelper', type: :helper do
  describe '#active_tab?' do
    before do
      allow(helper).to receive(:params).and_return(params)
    end

    context 'when no tab is selected' do
      let(:params) { {} }

      context 'and the tab is set as the default' do
        it 'returns true' do
          expect(helper.active_tab?(tab: 'foo', default_selected: true)).to eq(true)
        end
      end

      context 'and the tab is not set as the default' do
        it 'returns false' do
          expect(helper.active_tab?(tab: 'bar')).to eq(false)
        end
      end
    end

    context 'when a tab is selected' do
      let(:params) { { 'tab' => 'foo' } }

      context 'and the tab is the active one' do
        it 'returns true' do
          expect(helper.active_tab?(tab: 'foo')).to eq(true)
        end
      end

      context 'and the tab is not the active one' do
        it 'returns false' do
          expect(helper.active_tab?(tab: 'bar')).to eq(false)
        end
      end
    end
  end
end
