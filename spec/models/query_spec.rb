# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Query, type: :model do
  describe '#query_result' do
    let(:instance) { create(:query) }
    let(:query_service) { instance_double('QueryService') }

    subject { instance.query_result }

    before do
      allow(QueryService).to receive(:new).and_return(query_service)
      allow(query_service).to receive(:execute).and_return(query_service)
    end

    it 'returns an instance of the QueryService' do
      expect(subject).to eq(query_service)
    end

    it 'executes the query' do
      subject
      expect(query_service).to have_received(:execute)
    end
  end

  describe '#chart_config' do
    context 'when the config has not been set' do
      let(:instance) { create(:query) }

      it 'returns the defaults' do
        expect(instance.chart_config).to eq(
          x_axis_key: nil,
          x_axis_label: nil,
          x_axis_label_enabled: true,
          x_axis_gridlines_enabled: true,
          y_axis_key: nil,
          y_axis_label: nil,
          y_axis_label_enabled: true,
          y_axis_gridlines_enabled: false,
          title: nil,
          title_enabled: true,
          subtitle: nil,
          subtitle_enabled: true,
          legend_enabled: true,
          position: 'top',
          alignment: 'left',
          colors: [],
          tooltips_enabled: true,
          zooming_enabled: false
        )
      end
    end

    context 'when the config has been set' do
      let(:instance) { create(:query, chart_config:) }

      let(:chart_config) do
        {
          x_axis_key: 'x-axis-key',
          x_axis_label: 'X Axis Label',
          x_axis_label_enabled: true,
          x_axis_gridlines_enabled: true,
          y_axis_key: 'y-axis-key',
          y_axis_label: 'Y Axis Label',
          y_axis_label_enabled: true,
          y_axis_gridlines_enabled: false,
          title: 'My title',
          title_enabled: true,
          subtitle: 'My subtitle',
          subtitle_enabled: true,
          legend_enabled: true,
          position: 'bottom',
          alignment: 'centre',
          colors: [],
          tooltips_enabled: true,
          zooming_enabled: false
        }
      end

      it 'returns the stored config' do
        expect(instance.chart_config).to eq(chart_config)
      end
    end
  end
end
