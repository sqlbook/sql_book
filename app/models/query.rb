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

  def query_result
    @query_result ||= QueryService.new(query: self).execute
  end

  def chart_config
    return self[:chart_config].symbolize_keys unless self[:chart_config].empty?

    chart_config_detaults
  end

  private

  def normalize_boolean_fields
    self.chart_config = chart_config.transform_values do |val|
      val = true if val == '1'
      val = false if val == '0'
      val
    end
  end

  def chart_config_detaults
    {
      # Data accordion
      x_axis_key: query_result.columns.first,
      x_axis_label: query_result.columns.first&.humanize,
      x_axis_label_enabled: true,
      x_axis_gridlines_enabled: true,
      y_axis_key: query_result.columns.last,
      y_axis_label: query_result.columns.last&.humanize,
      y_axis_label_enabled: true,
      y_axis_gridlines_enabled: false,
      # Appearance accordion
      title: nil,
      title_enabled: true,
      subtitle: nil,
      subtitle_enabled: true,
      legend_enabled: true,
      position: 'bottom',
      colors: [],
      # Other accordion
      tooltips_enabled: true,
      zooming_enabled: false
    }
  end
end
