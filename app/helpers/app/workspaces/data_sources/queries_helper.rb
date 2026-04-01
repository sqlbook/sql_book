# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      module QueriesHelper
        def query_panel_title(query:)
          query.name.presence || I18n.t('app.workspaces.queries.editor.untitled_title')
        end

        def visualization_label(chart_type:)
          config = Visualizations::ChartRegistry.fetch(chart_type)
          I18n.t(config[:label_key])
        end

        def visualization_description(chart_type:)
          config = Visualizations::ChartRegistry.fetch(chart_type)
          I18n.t(config[:description_key])
        end
      end
    end
  end
end
