# frozen_string_literal: true

module Visualizations
  class Serializer
    class << self
      def call(query:, visualization:, include_preview: false)
        new(query:, visualization:, include_preview:).call
      end
    end

    def initialize(query:, visualization:, include_preview:)
      @query = query
      @visualization = visualization
      @include_preview = include_preview
    end

    def call
      return nil unless visualization

      payload = {
        'query_id' => query.id,
        'chart_type' => visualization.chart_type,
        'theme_reference' => visualization.theme_reference,
        'theme' => serialized_theme,
        'data_config' => visualization.resolved_data_config(query_result: query.query_result),
        'appearance_config_dark' => visualization.appearance_config_dark,
        'appearance_config_light' => visualization.appearance_config_light,
        'other_config' => visualization.resolved_other_config(query_result: query.query_result),
        'renderer' => Visualizations::ChartRegistry.fetch(visualization.chart_type)[:renderer]
      }

      payload['preview'] = preview_payload if include_preview
      payload
    end

    private

    attr_reader :query, :visualization, :include_preview

    def preview_payload
      {
        'dark_option' => OptionBuilder.new(query:, visualization:, mode: :dark).call,
        'light_option' => OptionBuilder.new(query:, visualization:, mode: :light).call
      }
    end

    def serialized_theme
      theme = visualization.selected_theme_entry
      return nil unless theme

      {
        'reference' => theme.reference_key,
        'name' => theme.name,
        'read_only' => theme.read_only?,
        'system_theme' => theme.system_theme?,
        'default' => theme.default?
      }
    end
  end
end
