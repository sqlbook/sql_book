# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::ThemeFormBuilder do
  describe '.build' do
    it 'applies generic axis colors to both category and value axis settings' do
      payload = described_class.build(
        theme_json: {},
        editor_params: {
          axis_line_color: '#444444',
          axis_label_color: '#888888',
          split_line_color: '#222222'
        },
        raw_json: nil
      )

      expect(payload.dig('categoryAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
      expect(payload.dig('valueAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
      expect(payload.dig('categoryAxis', 'axisLabel', 'color')).to eq('#888888')
      expect(payload.dig('valueAxis', 'axisLabel', 'color')).to eq('#888888')
      expect(payload.dig('categoryAxis', 'splitLine', 'lineStyle', 'color')).to eq('#222222')
      expect(payload.dig('valueAxis', 'splitLine', 'lineStyle', 'color')).to eq('#222222')
    end

    it 'prefers raw json when it is valid' do
      payload = described_class.build(
        theme_json: { 'backgroundColor' => '#111111' },
        editor_params: { background_color: '#222222' },
        raw_json: '{"backgroundColor":"#333333"}'
      )

      expect(payload).to eq({ 'backgroundColor' => '#333333' })
    end
  end
end
