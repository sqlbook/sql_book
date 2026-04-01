# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::ThemeUpsertService do
  let(:workspace) { create(:workspace) }

  it 'builds a workspace theme from editor params and marks it as default' do
    result = described_class.new(
      workspace:,
      attributes: {
        name: 'Board Room',
        default: 'true',
        editor_dark: {
          colors_csv: '#F5807B, #5CA1F2',
          background_color: '#1C1C1C',
          axis_label_color: '#BBBBBB'
        },
        raw_json_light: '{"backgroundColor":"#F4F2EE","color":["#FF6A64"]}'
      }
    ).call

    expect(result.success?).to eq(true)
    expect(result.theme.theme_json_dark['backgroundColor']).to eq('#1C1C1C')
    expect(result.theme.theme_json_dark['color']).to eq(%w[#F5807B #5CA1F2])
    expect(result.theme.theme_json_dark.dig('categoryAxis', 'axisLabel', 'color')).to eq('#BBBBBB')
    expect(result.theme.theme_json_light).to eq(
      'backgroundColor' => '#F4F2EE',
      'color' => ['#FF6A64']
    )
    expect(workspace.reload.default_visualization_theme).to eq(result.theme)
  end
end
