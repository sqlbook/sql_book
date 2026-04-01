# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryVisualization, type: :model do
  describe '#resolved_data_config' do
    it 'merges defaults from the query result columns for a cartesian chart' do
      query = create(:query)
      visualization = described_class.new(query:, chart_type: 'line', data_config: {})
      query_result = instance_double(QueryService, columns: %w[month revenue])

      expect(visualization.resolved_data_config(query_result:)).to include(
        'dimension_key' => 'month',
        'value_key' => 'revenue',
        'table_page_size' => 10
      )
    end
  end

  describe '#selected_theme_entry' do
    it 'falls back to the built-in system theme when the query has no workspace theme selected' do
      workspace = create(:workspace_with_owner, owner: create(:user))
      data_source = create(:data_source, workspace:)
      query = create(:query, data_source:)
      visualization = create(:query_visualization, query:, theme_reference: Visualizations::SystemTheme::REFERENCE_KEY)

      expect(visualization.selected_theme_entry).to be_a(Visualizations::SystemTheme)
      expect(visualization.selected_theme_entry.name).to eq('Default Theming')
    end
  end
end
