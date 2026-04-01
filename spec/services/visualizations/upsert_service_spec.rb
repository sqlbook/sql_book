# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::UpsertService do
  let(:workspace) { create(:workspace) }
  let(:default_theme) { create(:visualization_theme, workspace:, default: true, name: 'Workspace default') }
  let(:query) { create(:query, data_source: create(:data_source, workspace:)) }

  before do
    default_theme
  end

  it 'defaults to the workspace theme when no theme reference is supplied' do
    result = described_class.new(
      query:,
      workspace:,
      attributes: {
        chart_type: 'line',
        data_config: {
          dimension_key: 'month',
          value_key: 'revenue'
        }
      }
    ).call

    expect(result.success?).to eq(true)
    expect(query.reload.visualization.theme_reference).to eq(default_theme.reference_key)
  end

  it 'builds appearance overrides from editor params and raw json' do
    result = described_class.new(
      query:,
      workspace:,
      attributes: {
        chart_type: 'line',
        appearance_editor_dark: {
          colors_csv: '#F5807B, #5CA1F2',
          background_color: '#1C1C1C',
          axis_line_color: '#444444'
        },
        appearance_raw_json_light: '{"tooltip":{"backgroundColor":"#ffffff"}}'
      }
    ).call

    expect(result.success?).to eq(true)
    visualization = query.reload.visualization
    expect(visualization.appearance_config_dark.dig('categoryAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
    expect(visualization.appearance_config_dark.dig('valueAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
    expect(visualization.appearance_config_light).to eq({ 'tooltip' => { 'backgroundColor' => '#ffffff' } })
  end
end
