# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::OptionBuilder do
  let(:workspace) { create(:workspace) }
  let(:data_source) { create(:data_source, workspace:) }
  let(:query) { create(:query, data_source:) }
  let(:query_result) do
    instance_double(
      'QueryResult',
      error: false,
      columns: %w[month revenue],
      rows: [
        ['Jan', 10],
        ['Feb', 20]
      ]
    )
  end

  before do
    allow(query).to receive(:query_result).and_return(query_result)
  end

  it 'builds a cartesian echarts option using dataset and encode' do
    visualization = create(
      :query_visualization,
      query:,
      chart_type: 'line',
      data_config: { 'dimension_key' => 'month', 'value_key' => 'revenue' }
    )

    option = described_class.new(query:, visualization:, mode: :dark).call

    expect(option.dig('dataset', 'source')).to eq([
      %w[month revenue],
      ['Jan', 10],
      ['Feb', 20]
    ])
    expect(option.dig('series', 0, 'type')).to eq('line')
    expect(option.dig('series', 0, 'encode')).to eq({ 'x' => 'month', 'y' => 'revenue' })
  end

  it 'builds a donut option with the configured inner radius' do
    visualization = create(
      :query_visualization,
      query:,
      chart_type: 'donut',
      data_config: { 'dimension_key' => 'month', 'value_key' => 'revenue' },
      other_config: { 'donut_inner_radius' => '64%' }
    )

    option = described_class.new(query:, visualization:, mode: :light).call

    expect(option.dig('series', 0, 'type')).to eq('pie')
    expect(option.dig('series', 0, 'radius')).to eq(['64%', '78%'])
  end

  it 'returns nil for non-echarts visualization types' do
    visualization = create(:query_visualization, query:, chart_type: 'table')

    expect(described_class.new(query:, visualization:, mode: :dark).call).to eq(nil)
  end

  it 'returns nil when the query result is in an error state' do
    allow(query).to receive(:query_result).and_return(
      instance_double('QueryResult', error: true, columns: [], rows: [])
    )
    visualization = create(:query_visualization, query:, chart_type: 'line')

    expect(described_class.new(query:, visualization:, mode: :dark).call).to eq(nil)
  end
end
