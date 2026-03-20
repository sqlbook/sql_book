# frozen_string_literal: true

class GeneralizeDataSourcesForConnectors < ActiveRecord::Migration[7.1]
  def up
    add_column :data_sources, :name, :string
    add_column :data_sources, :source_type, :integer, default: 0, null: false
    add_column :data_sources, :status, :integer, default: 0, null: false
    add_column :data_sources, :last_checked_at, :datetime
    add_column :data_sources, :last_error, :text
    add_column :data_sources, :config, :jsonb, default: {}, null: false
    add_column :data_sources, :encrypted_connection_password, :text

    remove_index :data_sources, :url
    add_index :data_sources, [:workspace_id, :url], unique: true, where: 'url IS NOT NULL'
    add_index :data_sources, [:workspace_id, :source_type]

    change_column_null :data_sources, :url, true

    execute <<~SQL.squish
      UPDATE data_sources
      SET
        name = COALESCE(NULLIF(url, ''), 'Data source ' || id),
        source_type = 0,
        status = CASE WHEN verified_at IS NULL THEN 0 ELSE 1 END,
        config = '{}'::jsonb
    SQL

    change_column_null :data_sources, :name, false
  end

  def down
    change_column_null :data_sources, :url, false
    change_column_null :data_sources, :name, true

    remove_index :data_sources, column: [:workspace_id, :source_type]
    remove_index :data_sources, column: [:workspace_id, :url]
    add_index :data_sources, :url, unique: true

    remove_column :data_sources, :encrypted_connection_password
    remove_column :data_sources, :config
    remove_column :data_sources, :last_error
    remove_column :data_sources, :last_checked_at
    remove_column :data_sources, :status
    remove_column :data_sources, :source_type
    remove_column :data_sources, :name
  end
end
