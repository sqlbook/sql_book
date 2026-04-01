# frozen_string_literal: true

class AllowMultipleQueryVisualizationsPerChartType < ActiveRecord::Migration[8.0]
  def change
    remove_index :query_visualizations, :query_id
    add_index :query_visualizations, %i[query_id chart_type], unique: true
  end
end
