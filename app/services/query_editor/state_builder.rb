# frozen_string_literal: true

module QueryEditor
  class StateBuilder # rubocop:disable Metrics/ClassLength
    class << self
      def call(workspace:, query:, data_source:, query_chat_source: nil, active_tab: nil)
        new(
          workspace:,
          query:,
          data_source:,
          query_chat_source:,
          active_tab:
        ).call
      end
    end

    def initialize(workspace:, query:, data_source:, query_chat_source:, active_tab:)
      @workspace = workspace
      @query = query
      @data_source = data_source
      @query_chat_source = query_chat_source
      @active_tab = active_tab.to_s.presence || 'query_results'
    end

    def call
      {
        'query' => serialized_query,
        'result' => serialized_query_result,
        'run_token' => initial_run_token,
        'visualizations' => serialized_visualizations,
        'available_visualization_types' => Visualizations::ChartRegistry.available.map do |config|
          config.merge(
            label: I18n.t(config[:label_key]),
            description: I18n.t(config[:description_key])
          )
        end,
        'theme_library' => serialized_theme_library,
        'chat_source' => query_chat_source,
        'active_tab' => normalized_active_tab
      }
    end

    private

    attr_reader :workspace, :query, :data_source, :query_chat_source, :active_tab

    def serialized_query
      {
        'id' => query.persisted? ? query.id : nil,
        'saved' => query.saved,
        'name' => query.name,
        'sql' => query.query,
        'data_source_id' => data_source.id,
        'canonical_path' => canonical_path
      }
    end

    def canonical_path
      return nil unless query.persisted?

      Rails.application.routes.url_helpers.app_workspace_data_source_query_path(
        workspace,
        data_source,
        query
      )
    end

    def serialized_query_result
      return nil unless query.persisted?

      result = query.query_result
      {
        'error' => result.error,
        'error_message' => result.error_message,
        'columns' => result.columns,
        'rows' => result.rows,
        'row_count' => result.rows.length
      }
    end

    def initial_run_token
      return nil unless query.persisted?
      return nil if query.query_result.error

      RunToken.issue(data_source_id: data_source.id, sql: query.query)
    end

    def serialized_visualizations
      return [] unless query.persisted?

      query.visualizations.order(:chart_type).map { |visualization| serialized_visualization(visualization) }
    end

    def serialized_theme_library
      Visualizations::ThemeLibraryService.call(workspace:).map do |theme_entry|
        {
          'id' => theme_entry.id,
          'reference_key' => theme_entry.reference_key,
          'name' => theme_entry.name,
          'default' => theme_entry.default?,
          'read_only' => theme_entry.read_only?,
          'system_theme' => theme_entry.system_theme?,
          'theme_json_dark' => theme_entry.theme_json_dark,
          'theme_json_light' => theme_entry.theme_json_light
        }
      end
    end

    def normalized_active_tab
      %w[query_results visualization settings].include?(active_tab) ? active_tab : 'query_results'
    end

    def serialized_visualization(visualization)
      editor_dark = editor_attributes_for(visualization:, mode: :dark)
      editor_light = editor_attributes_for(visualization:, mode: :light)

      Visualizations::Serializer.call(
        query:,
        visualization:,
        include_preview: false
      ).merge(
        'appearance_editor_dark' => editor_dark.except(:raw_json).deep_stringify_keys,
        'appearance_editor_light' => editor_light.except(:raw_json).deep_stringify_keys,
        'appearance_raw_json_dark' => editor_dark[:raw_json],
        'appearance_raw_json_light' => editor_light[:raw_json]
      )
    end

    def editor_attributes_for(visualization:, mode:)
      Visualizations::ThemeFormBuilder.editor_attributes(
        theme_json: visualization.appearance_config_for(mode:)
      )
    end
  end # rubocop:enable Metrics/ClassLength
end
