# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::ThemePreviewBuilder do
  describe '.call' do
    it 'returns palette swatches and sample options for common chart families' do
      preview = described_class.call(
        theme_json: {
          'color' => %w[#F5807B #5CA1F2 #F8BD77],
          'backgroundColor' => '#1C1C1C',
          'textStyle' => { 'color' => '#ECEAE6' }
        }
      )

      expect(preview[:palette]).to eq(%w[#F5807B #5CA1F2 #F8BD77])
      expect(preview[:charts].keys).to contain_exactly('line', 'bar', 'donut')
      expect(preview[:charts].fetch('line').dig('series', 0, 'type')).to eq('line')
      expect(preview[:charts].fetch('donut').dig('series', 0, 'radius')).to eq(['52%', '72%'])
    end
  end
end
