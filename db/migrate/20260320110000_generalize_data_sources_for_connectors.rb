# frozen_string_literal: true

class GeneralizeDataSourcesForConnectors < ActiveRecord::Migration[7.1]
  def up
    change_table :data_sources, bulk: true do |table|
      table.string :name
      table.integer :source_type, default: 0, null: false
      table.integer :status, default: 0, null: false
      table.datetime :last_checked_at
      table.text :last_error
      table.jsonb :config, default: {}, null: false
      table.text :encrypted_connection_password
    end

    remove_index :data_sources, :url
    add_index :data_sources, %i[workspace_id url], unique: true, where: 'url IS NOT NULL'
    add_index :data_sources, %i[workspace_id source_type]

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
    # rubocop:disable Rails/BulkChangeTable
    change_column_null :data_sources, :url, false
    change_column_null :data_sources, :name, true
    # rubocop:enable Rails/BulkChangeTable

    remove_index :data_sources, column: %i[workspace_id source_type]
    remove_index :data_sources, column: %i[workspace_id url]
    add_index :data_sources, :url, unique: true

    change_table :data_sources, bulk: true do |table|
      table.remove :encrypted_connection_password
      table.remove :config
      table.remove :last_error
      table.remove :last_checked_at
      table.remove :status
      table.remove :source_type
      table.remove :name
    end
  end
end
