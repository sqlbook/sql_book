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
    expect(query.reload.visualizations.find_by(chart_type: 'line')&.theme_reference).to eq(default_theme.reference_key)
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
    visualization = query.reload.visualizations.find_by(chart_type: 'line')
    expect(visualization.appearance_config_dark.dig('categoryAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
    expect(visualization.appearance_config_dark.dig('valueAxis', 'axisLine', 'lineStyle', 'color')).to eq('#444444')
    expect(visualization.appearance_config_light).to eq({ 'tooltip' => { 'backgroundColor' => '#ffffff' } })
  end

  it 'upserts the targeted chart type without overwriting another saved visualization' do
    create(:query_visualization, query:, chart_type: 'pie')

    described_class.new(
      query:,
      workspace:,
      chart_type: 'line',
      attributes: {
        data_config: {
          dimension_key: 'month',
          value_key: 'revenue'
        }
      }
    ).call

    expect(query.reload.visualizations.order(:chart_type).pluck(:chart_type)).to eq(%w[line pie])
  end
end
