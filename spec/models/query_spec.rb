# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Query, type: :model do
  let(:instance) { create(:query) }

  let(:query_service_columns) { [] }
  let(:query_service) { instance_double('QueryService', columns: query_service_columns) }

  before do
    allow(QueryService).to receive(:new).and_return(query_service)
    allow(query_service).to receive(:execute).and_return(query_service)
  end

  describe '#query_result' do
    subject { instance.query_result }

    it 'returns an instance of the QueryService' do
      expect(subject).to eq(query_service)
    end

    it 'executes the query' do
      subject
      expect(query_service).to have_received(:execute)
    end
  end

  describe '#before_save' do
    it 'converts "1" and "0" to booleans' do
      instance.update(chart_config: { x_axis_label_enabled: '1' })

      expect(instance.reload.chart_config[:x_axis_label_enabled]).to eq(true)
    end
  end

  describe '#chart_config' do
    context 'when the config has not been set' do
      let(:query_service_columns) { %w[col_1 col_2] }

      it 'returns the defaults' do
        expect(instance.chart_config).to eq(
          x_axis_key: 'col_1',
          x_axis_label: 'Col 1',
          x_axis_label_enabled: true,
          x_axis_gridlines_enabled: true,
          y_axis_key: 'col_2',
          y_axis_label: 'Col 2',
          y_axis_label_enabled: true,
          y_axis_gridlines_enabled: false,
          title: 'Title',
          title_enabled: true,
          subtitle: 'Subtitle text string',
          subtitle_enabled: true,
          legend_enabled: true,
          legend_position: 'top',
          legend_alignment: 'start',
          colors: ['#F5807B', '#5CA1F2', '#F8BD77', '#B2405B', '#D97FC6', '#F0E15A', '#95A7B1', '#6CCB5F'],
          data_column: 'col_1',
          pagination_enabled: true,
          pagination_rows: 10,
          post_text_label: 'post-text-label',
          post_text_label_enabled: true,
          post_text_label_position: 'right',
          tooltips_enabled: true
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
          legend_position: 'top',
          legend_alignment: 'center',
          colors: [],
          tooltips_enabled: true
        }
      end

      it 'returns the stored config' do
        expect(instance.chart_config).to eq(chart_config)
      end
    end
  end
end
