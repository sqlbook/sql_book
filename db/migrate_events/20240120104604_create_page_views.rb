# frozen_string_literal: true

class CreatePageViews < ActiveRecord::Migration[7.1]
  def up
    create_table :page_views, id: :uuid, primary_key: :uuid do |t|
      t.uuid :data_source_uuid, null: false
      t.uuid :session_uuid, null: false
      t.uuid :visitor_uuid, null: false
      t.bigint :timestamp, null: false
      t.string :url, null: false
    end

    add_index :page_views, :data_source_uuid

    # Enable RLS for this table
    execute <<-SQL.squish
      ALTER TABLE page_views
      ENABLE ROW LEVEL SECURITY
    SQL

    # Ensure the table owner is also subject to RLS
    execute <<-SQL.squish
      ALTER TABLE page_views
      FORCE ROW LEVEL SECURITY
    SQL

    # Set a policy on this table to scope the requests to the data source
    execute <<-SQL.squish
      CREATE POLICY page_views_policy ON page_views
      FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid)
    SQL
  end

  def down
    drop_table :page_views
  end
end
