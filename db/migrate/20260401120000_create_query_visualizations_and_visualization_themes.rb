# frozen_string_literal: true

class CreateQueryVisualizationsAndVisualizationThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :query_visualizations do |t|
      t.references :query, null: false, foreign_key: true, index: { unique: true }
      t.string :chart_type, null: false
      t.string :theme_reference, null: false, default: 'system.default_theming'
      t.jsonb :data_config, null: false, default: {}
      t.jsonb :appearance_config_dark, null: false, default: {}
      t.jsonb :appearance_config_light, null: false, default: {}
      t.jsonb :other_config, null: false, default: {}

      t.timestamps
    end

    create_table :visualization_themes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :theme_json_dark, null: false, default: {}
      t.jsonb :theme_json_light, null: false, default: {}
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    add_index :visualization_themes, [:workspace_id, :name], unique: true
    add_index :visualization_themes,
              :workspace_id,
              unique: true,
              where: '"default" = true',
              name: "index_visualization_themes_on_workspace_id_where_default"

    remove_column :queries, :chart_type, :string
    remove_column :queries, :chart_config, :jsonb, default: {}, null: false
  end
end
