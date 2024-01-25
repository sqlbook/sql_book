# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      module QueriesHelper
        def chart_label(chart_type:)
          Rails.configuration.charts[chart_type][:label]
        end
      end
    end
  end
end
