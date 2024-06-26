# frozen_string_literal: true

class Query < ApplicationRecord
  belongs_to :data_source

  belongs_to :author,
             class_name: 'User',
             primary_key: :id

  belongs_to :last_updated_by,
             class_name: 'User',
             primary_key: :id,
             optional: true

  normalizes :chart_type, with: ->(chart_type) { chart_type.presence }

  before_save :normalize_boolean_fields

  # Changing any of the chart config will not impact
  # the query results, so only clear the cache if
  # that specific field is changed
  before_update :clear_query_cache!, if: :will_save_change_to_query?

  def query_result
    @query_result ||= query_service.execute
  end

  def chart_config
    return self[:chart_config].symbolize_keys unless self[:chart_config].empty?

    chart_config_detaults
  end

  private

  def clear_query_cache!
    query_service.clear_cache!
  end

  def query_service
    @query_service ||= QueryService.new(query: self)
  end

  def normalize_boolean_fields
    self.chart_config = chart_config.transform_values do |val|
      val = true if val == '1'
      val = false if val == '0'
      val
    end
  end

  def chart_config_detaults # rubocop:disable Metrics/AbcSize
    {
      x_axis_key: query_result.columns.first,
      x_axis_label: query_result.columns.first&.humanize,
      x_axis_label_enabled: true,
      x_axis_gridlines_enabled: true,
      y_axis_key: query_result.columns.last,
      y_axis_label: query_result.columns.last&.humanize,
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
      tooltips_enabled: true,
      data_column: query_result.columns.first,
      post_text_label_enabled: true,
      post_text_label: 'post-text-label',
      post_text_label_position: 'right',
      pagination_rows: 10,
      pagination_enabled: true,
      circumference: 50
    }
  end
end
