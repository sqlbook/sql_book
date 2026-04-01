# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources::QueriesHelper', type: :helper do
  describe '#visualization_label' do
    it 'returns the label for the visualization type' do
      expect(helper.visualization_label(chart_type: 'line')).to eq('Line')
      expect(helper.visualization_label(chart_type: 'donut')).to eq('Donut')
    end
  end

  describe '#visualization_description' do
    it 'returns the localized description for the visualization type' do
      expect(helper.visualization_description(chart_type: 'table')).to include('formatted table')
    end
  end
end
