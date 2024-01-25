# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources::QueriesHelper', type: :helper do
  describe '#chart_label' do
    it 'returns the label for the chart_type' do
      expect(helper.chart_label(chart_type: 'line')).to eq('Line')
      expect(helper.chart_label(chart_type: 'stacked_area')).to eq('Stacked area')
    end
  end
end
